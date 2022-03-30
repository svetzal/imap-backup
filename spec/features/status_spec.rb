require "features/helper"
require "imap/backup/cli/status"

RSpec.describe "status", type: :aruba, docker: true do
  include_context "account fixture"
  include_context "message-fixtures"

  let(:options) { {accounts: account.username} }

  context "when there are non-backed-up messages" do
    let(:folder) { "my-stuff" }

    before do
      server_create_folder folder
      send_email folder, msg1
      send_email folder, msg2
      create_config(accounts: [account.to_h])

      run_command_and_stop("imap-backup status")
    end

    after do
      server_delete_folder folder
      disconnect_imap
    end

    it "prints the count of messages to download" do
      puts "last_command_started.output: #{last_command_started.output}"
    end
  end
end
