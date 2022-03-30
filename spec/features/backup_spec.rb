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
    expect(mbox_content(folder)).to eq(messages_as_mbox)
  end

  describe "IMAP metadata" do
    let(:imap_metadata) { imap_parsed(folder) }
    let(:folder_uids) { server_uids(folder) }

    it "saves IMAP metadata in a JSON file" do
      expect { imap_metadata }.to_not raise_error
    end

    it "saves a file version" do
      expect(imap_metadata[:version].to_s).to match(/^[0-9.]$/)
    end

    it "records IMAP ids" do
      expect(imap_metadata[:uids]).to eq(folder_uids)
    end

    it "records uid_validity" do
      expect(imap_metadata[:uid_validity]).to eq(server_uid_validity(folder))
    end
  end
end
