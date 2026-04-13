# Module for a class that automatically records its subclasses.
module Fumimi::ClassRegister
  def self.included(base)
    base.extend(ClassMethods)
    base.singleton_class.prepend(InheritedHook)
  end

  module InheritedHook
    def inherited(subclass)
      subclasses << subclass
      super
    end
  end

  module ClassMethods
    def subclasses
      @subclasses ||= []
    end

    def register_all(**opts)
      subclasses.each do |command|
        register(command, **opts)
      end
    end

    def register(**opts)
      raise NotImplementedError
    end
  end
end
