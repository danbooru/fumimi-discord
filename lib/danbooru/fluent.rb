module Fluent
  def attr_fluent(*attrs)
    attr_accessor(*attrs)

    attrs.each do |attr|
      define_method(attr) do |*args|                        # define name(*args)
        dup.send("#{attr}!", *args)                         #  dup.send("name!", *args)
      end                                                   # end

      define_method("#{attr}!") do |*args|                  # define name!(*args)
        case args.size                                      #   case args.size
        when 0                                              #   when 0
          instance_variable_get("@#{attr}")                 #     @name
        when 1                                              #   when 1
          old_value = send(attr)                            #     old_value = @name
          new_value = args.first                            #     new_value = args.first

          if new_value.is_a?(Hash) && old_value.is_a?(Hash) #     if new_value.is_a?(Hash) && old_value.is_a?(Hash)
            new_value = old_value.merge(new_value)          #       new_value = old_value.merge(new_value)
          end                                               #     end

          instance_variable_set("@#{attr}", new_value)      #     @name = new_value
          self                                              #     self
        else                                                #   else
          error  = "wrong number of arguments"              #     error  = "wrong number of arguments"
          error << "(given #{args.size}, expected 0 or 1)"  #     error << "(given #{args.size}, expected 0 or 1)"
          raise ArgumentError, error                        #     raise ArgumentError, error
        end                                                 #   end
      end                                                   # end
    end
  end
end
