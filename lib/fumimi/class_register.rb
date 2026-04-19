# Module for automatically tracking and registering subclasses.
#
# This module provides a class registry pattern that automatically records all subclasses
# and provides methods to register and iterate over them. It's used as a mixin for base
# classes like SlashCommand and Event to enable dynamic discovery and registration of
# all command/event implementations without explicit registration code.
#
# Usage:
#   class MyBase
#     include Fumimi::ClassRegister
#
#     def self.register(subclass, **opts)
#       # Custom registration logic here
#     end
#   end
#
#   class MySubclass < MyBase
#     # Automatically added to MyBase.subclasses
#   end
#
#   MyBase.register_all(**opts)  # Registers all subclasses
#
module Fumimi::ClassRegister
  # Initializes the module when included by extending the base class with class methods
  # and setting up the inherited hook to track subclasses.
  #
  # @param base [Class] the class including this module
  # @return [void]
  def self.included(base)
    base.extend(ClassMethods)
    base.singleton_class.prepend(InheritedHook)
  end

  # Hook that tracks when a new subclass is created.
  module InheritedHook
    # Called automatically when a subclass is created. Adds the subclass to the registry.
    #
    # @param subclass [Class] the new subclass that is being created
    # @return [void]
    def inherited(subclass)
      subclasses << subclass
      super
    end
  end

  # Class methods added to the including class for managing subclasses.
  module ClassMethods
    # Returns the array of all registered subclasses.
    #
    # @return [Array<Class>] array of subclasses
    def subclasses
      @subclasses ||= []
    end

    # Registers all tracked subclasses with the provided options.
    # Calls {#register} for each subclass with the given options.
    #
    # @param opts [Hash] keyword arguments passed to {#register}
    # @return [void]
    def register_all(**opts)
      subclasses.each do |command|
        register(command, **opts)
      end
    end

    # Registers a single subclass. Must be implemented by the including class.
    #
    # @param opts [Hash] keyword arguments for registration
    # @raise [NotImplementedError] if not overridden by including class
    def register(**opts)
      raise NotImplementedError
    end
  end
end
