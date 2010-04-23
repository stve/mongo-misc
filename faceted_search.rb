# http://ianwarshak.posterous.com/faceted-search-with-mongodb
#
# Example:
# Book.create(:title => 'Jurassic Park', :author => 'Michael Crichton', :authors => ['Michael Crichton'], :genre => ['fiction'], :keywords => ['velociraptor', 'clever girl'], :rating => [4])
# Book.create(:title => 'Sphere', :author => 'Michael Crichton', :authors => ['Michael Crichton'], :genre => ['fiction'], :keywords => ['ocean'], :rating => [5])
# Book.create(:title => 'The Firm', :author => 'John Grisham', :authors => ['John Grisham'], :genre => ['fiction'], :keywords => ['law', 'lawyer'], :rating => [4])
#
# irb(main):237:0> Book.facet_search("authors" => {"$in" => ['John Grisham']})
# => {"rating"=>{4.0=>1.0}, "genre"=>{"fiction"=>1.0}, "authors"=>{"John Grisham"=>1.0}, "keywords"=>{"law"=>1.0, "lawyer"=>1.0}}
#
# irb(main):241:0> Book.facet_search("authors" => {"$in" => ['Michael Crichton']}, :rating => {"$in" => [5]})
# => {"rating"=>{5.0=>1.0}, "genre"=>{"fiction"=>1.0}, "authors"=>{"Michael Crichton"=>1.0}, "keywords"=>{"ocean"=>1.0}}

class Book
  include MongoMapper::Document
  CONTEXTS = ['authors', 'rating','keywords', 'genre']
  CONTEXTS.each do |context|
    key context, Array, :index => true
  end
  
  key :title, String
  key :contexts, Array
  
  before_create :set_contexts
  
  def set_contexts
    self.contexts = CONTEXTS
  end
  
  def self.facet_search(query = {})
    map = <<-MAP
function() {
var that = this;
this.contexts.forEach(function(context) {
that[context].forEach(function(tag) {
print('!!!!!emitting. tag: ' + tag + ', { ' + context +' : 1 }');
t = {};
t[context] = 1
emit(tag, t)
});
});
}
MAP

    reduce = <<-REDUCE
function(tag, values) {
res = {};
print('!!tag: ' + tag + ' values: ' + tojson(values));
values.forEach(function(tuple) {
for(context in tuple) {
if(res[context] === undefined) {
print(tag + ' is undefined for ' + context + ' setting to ' + tuple[context]);
res[context] = tuple[context];
} else {
print(tag + ' is currently ' + res[context] + ' incrementing by ' + tuple[context]);
res[context] += tuple[context];
}
}
});

print("returning tag: " + tag + " values: " + tojson(res));

return res;
}
REDUCE
    
    sort_facets(self.collection.map_reduce(map, reduce,{:query => query }))
  end
  
  private
  def self.sort_facets(t)
    contexts = {}
    t.find.each do |res|
      res["value"].keys.each do |ctxt|
        contexts[ctxt] ||= {}
        contexts[ctxt][res['_id']] ||= 0
        contexts[ctxt][res['_id']] += res["value"][ctxt]
      end
    end
    contexts
  end
  
end