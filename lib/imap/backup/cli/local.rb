require "imap/backup/cli/accounts"

module Imap::Backup
  class CLI::Local < Thor
    include Thor::Actions
    include CLI::Helpers

    MAX_SUBJECT = 60

    desc "accounts", "List locally backed-up accounts"
    def accounts
      accounts = CLI::Accounts.new
      accounts.each { |a| Kernel.puts a.username }
    end

    desc "folders EMAIL", "List backed up folders"
    def folders(email)
      connection = connection(email)

      connection.local_folders.each do |_s, f|
        Kernel.puts %("#{f.name}")
      end
    end

    desc "list EMAIL FOLDER", "List emails in a folder"
    def list(email, folder_name)
      connection = connection(email)

      folder_serializer, _folder = connection.local_folders.find do |(_s, f)|
        f.name == folder_name
      end
      raise "Folder '#{folder_name}' not found" if !folder_serializer

      Kernel.puts format(
        "%-10<uid>s  %-#{MAX_SUBJECT}<subject>s - %<date>s",
        {uid: "UID", subject: "Subject", date: "Date"}
      )
      Kernel.puts "-" * (12 + MAX_SUBJECT + 28)

      uids = folder_serializer.uids

      folder_serializer.each_message(uids).map do |uid, message|
        list_message uid, message
      end
    end

    desc "show EMAIL FOLDER UID[,UID]", "Show one or more emails"
    long_desc <<~DESC
      Prints out the requested emails.
      If more than one UID is given, they are separated by a header indicating
      the UID.
    DESC
    def show(email, folder_name, uids)
      connection = connection(email)

      folder_serializer, _folder = connection.local_folders.find do |(_s, f)|
        f.name == folder_name
      end
      raise "Folder '#{folder_name}' not found" if !folder_serializer

      uid_list = uids.split(",")
      folder_serializer.each_message(uid_list).each do |uid, message|
        if uid_list.count > 1
          Kernel.puts <<~HEADER
            #{'-' * 80}
            #{format('| UID: %-71s |', uid)}
            #{'-' * 80}
          HEADER
        end
        Kernel.puts message.supplied_body
      end
    end

    no_commands do
      def list_message(uid, message)
        m = {
          uid: uid,
          date: message.date.to_s,
          subject: message.subject || ""
        }
        if m[:subject].length > MAX_SUBJECT
          Kernel.puts format("% 10<uid>u: %.#{MAX_SUBJECT - 3}<subject>s... - %<date>s", m)
        else
          Kernel.puts format("% 10<uid>u: %-#{MAX_SUBJECT}<subject>s - %<date>s", m)
        end
      end
    end
  end
end
