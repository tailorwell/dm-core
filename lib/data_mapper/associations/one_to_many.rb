require 'forwardable'

module DataMapper
  module Associations
    module OneToMany
      OPTIONS = [ :class_name, :child_key, :parent_key, :min, :max ]

      private

      def one_to_many(name, options = {})
        raise ArgumentError, "+name+ should be a Symbol (or Hash for +through+ support), but was #{name.class}", caller     unless Symbol === name || Hash === name
        raise ArgumentError, "+options+ should be a Hash, but was #{options.class}", caller unless Hash   === options

        child_model_name = options.fetch(:class_name, DataMapper::Inflection.classify(name))

        relationship = relationships(repository.name)[name] = Relationship.new(
          DataMapper::Inflection.underscore(self.name.split('::').last).to_sym,
          repository.name,
          child_model_name,
          self.name,
          options
        )

        class_eval <<-EOS, __FILE__, __LINE__
          def #{name}
            @#{name}_association ||= begin
              relationship = self.class.relationships(repository.name)[#{name.inspect}]
              raise ArgumentError.new("Relationship #{name.inspect} does not exist") unless relationship
              association = Proxy.new(relationship, self)
              parent_associations << association
              association
            end
          end

          def #{name}=(children)
            #{name}.replace(children)
          end
        EOS

        relationship
      end

      class Proxy
        instance_methods.each { |m| undef_method m unless %w[ __id__ __send__ class kind_of? should should_not ].include?(m) }

        def replace(resources)
          each { |resource| remove_resource(resource) }
          append_resource(resources)
          children.replace(resources)
          self
        end

        def push(*resources)
          append_resource(resources)
          children.push(*resources)
          self
        end

        def unshift(*resources)
          append_resource(resources)
          children.unshift(*resources)
          self
        end

        def <<(resource)
          append_resource([ resource ])
          children << resource
          self
        end

        def pop
          remove_resource(children.pop)
        end

        def shift
          remove_resource(children.shift)
        end

        def delete(resource, &block)
          remove_resource(children.delete(resource, &block))
        end

        def delete_at(index)
          remove_resource(children.delete_at(index))
        end

        def clear
          each { |resource| remove_resource(resource) }
          children.clear
          self
        end

        def save
          save_resources(@dirty_children)
          @dirty_children = []
          self
        end

        private

        def initialize(relationship, parent_resource)
#          raise ArgumentError, "+relationship+ should be a DataMapper::Association::Relationship, but was #{relationship.class}", caller unless Relationship === relationship
#          raise ArgumentError, "+parent_resource+ should be a DataMapper::Resource, but was #{parent_resource.class}", caller            unless Resource     === parent_resource

          @relationship    = relationship
          @parent_resource = parent_resource
          @dirty_children  = []
        end

        def children
          @children ||= @relationship.get_children(@parent_resource)
        end

        def remove_resource(resource)
          begin
            repository(@relationship.repository_name) do
              @relationship.attach_parent(resource, nil)
              resource.save
            end
          rescue
            children << resource
            raise
          end
          resource
        end

        def append_resource(resources = [])
          if @parent_resource.new_record?
            @dirty_children.push(*resources)
          else
            save_resources(resources)
          end
        end

        def save_resources(resources = [])
          repository(@parent_resource.repository.name) do
            resources.each do |resource|
              @relationship.attach_parent(resource, @parent_resource)
              resource.save
            end
          end
        end

        def method_missing(method, *args, &block)
          children.__send__(method, *args, &block)
        end
      end # class Proxy
    end # module OneToMany
  end # module Associations
end # module DataMapper
