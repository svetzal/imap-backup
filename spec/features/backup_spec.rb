require "features/helper"

RSpec.describe "backup", type: :aruba, docker: true do
  include_context "account fixture"
  include_context "message-fixtures"

  let(:backup_folders) { [{name: folder}] }
  let(:folder) { "my-stuff" }
  let(:messages_as_mbox) do
    message_as_mbox_entry(msg1) + message_as_mbox_entry(msg2)
  end

  let!(:pre) {}
  let!(:setup) do
    server_create_folder folder
    send_email folder, msg1
    send_email folder, msg2
    create_config(accounts: [account.to_h])

    run_command_and_stop("imap-backup backup")
  end

  after do
    server_delete_folder folder
    disconnect_imap
  end

  it "downloads messages" do
    puts "last_command_started.output: #{last_command_started.output}"
  end
end
