# http://gist.github.com/297400

module MongoMapper
  module FindRandom
    def self.included(document)
      document.extend ClassMethods
    end


    module ClassMethods
      # Fetch random document from MongoDb
      def find_random(conditions = {})
        options = {}
        options[:conditions] = conditions
        options[:skip] = rand(self.collection.count)
        self.find(:first, options)
      end
    end
  end
end
