module Imap::Backup
  class Migrator
    attr_reader :folder
    attr_reader :reset
    attr_reader :serializer

    def initialize(serializer, folder, reset: false)
      @folder = folder
      @reset = reset
      @serializer = serializer
    end

    def run
      count = serializer.uids.count
      folder.create
      ensure_destination_empty!

      Logger.logger.debug "[#{folder.name}] #{count} to migrate"
      serializer.each_message(serializer.uids).with_index do |(uid, message), i|
        next if message.nil?

        log_prefix = "[#{folder.name}] uid: #{uid} (#{i + 1}/#{count}) -"
        Logger.logger.debug(
          "#{log_prefix} #{message.supplied_body.size} bytes"
        )

        folder.append(message)
      end
    end

    private

    def ensure_destination_empty!
      if reset
        folder.clear
      else
        fail_if_destination_not_empty!
      end
    end

    def fail_if_destination_not_empty!
      return if folder.uids.empty?

      raise <<~ERROR
        The destination folder '#{folder.name}' is not empty.
        Pass the --reset flag if you want to clear existing emails from destination
        folders before uploading.
      ERROR
    end
  end
end
