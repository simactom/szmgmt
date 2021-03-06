module SZMGMT
  module SZONES
    module Exceptions
      class NoSuchZoneError < SZONESError
        def initialize(command, stderr)
          SZMGMT.logger.error("NoSuchZoneError - No such zone exists (#{command}).")
          SZMGMT.logger.error("----> (stderr) #{stderr}")
          super(stderr)
        end
      end
    end
  end
end