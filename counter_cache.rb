# http://www.coffeepowered.net/2010/02/15/counter_cache-for-mongomapper/
#
# Example:
# class Foo
#   include MongoMapper::Document
#   include SecretProject::CounterCache
# 
#   belongs_to :user
#   counter_cache :user  # Will cause a foos_count field on the owning user to be maintained when a Foo is created or deleted.
# end


module SecretProject
  module CounterCache
    module ClassMethods
      def counter_cache(field)
        class_eval <<-EOF
          after_create "increment_counter_for_#{field}"
          after_destroy "decrement_counter_for_#{field}"
        EOF
      end
    end

    module InstanceMethods
      def method_missing(method, *args)
        if matches = method.to_s.match(/^(in|de)crement_counter_for_(.*)$/) then
          dir = matches[1] == "in" ? 1 : -1
          parent_association = matches[2]
          if parent = self.send(parent_association) then
            name = "#{self.class.to_s.tableize}_count"
            if parent.respond_to?(name)
              parent.collection.update({:_id => parent._id}, {"$inc" => {name => dir}})
            end
          end
        else
          super
        end
      end
    end

    def self.included(receiver)
      receiver.extend         ClassMethods
      receiver.send :include, InstanceMethods
    end
  end
end
