# rubocop:disable RSpec/PredicateMatcher

describe Imap::Backup::Account::Folder do
  FOLDER_NAME = "Gelöscht".freeze
  ENCODED_FOLDER_NAME = "Gel&APY-scht".freeze

  subject { described_class.new(connection, FOLDER_NAME) }

  let(:client) do
    instance_double(
      Imap::Backup::Client::Default,
      append: append_response,
      create: nil,
      examine: nil,
      expunge: nil,
      responses: responses,
      select: nil,
      uid_store: nil
    )
  end
  let(:connection) do
    instance_double(Imap::Backup::Account::Connection, client: client)
  end
  let(:missing_mailbox_data) do
    OpenStruct.new(text: "Unknown Mailbox: #{FOLDER_NAME}")
  end
  let(:missing_mailbox_response) { OpenStruct.new(data: missing_mailbox_data) }
  let(:missing_mailbox_error) do
    Net::IMAP::NoResponseError.new(missing_mailbox_response)
  end
  let(:responses) { [] }
  let(:append_response) { nil }
  let(:uids) { [5678, 123] }

  before { allow(client).to receive(:uid_search) { uids } }

  describe "#uids" do
    it "lists available messages" do
      expect(subject.uids).to eq(uids.reverse)
    end

    context "with missing mailboxes" do
      before do
        allow(client).to receive(:examine).
          with(ENCODED_FOLDER_NAME).and_raise(missing_mailbox_error)
      end

      it "returns an empty array" do
        expect(subject.uids).to eq([])
      end
    end

    context "with no SEARCH response in Net::IMAP" do
      let(:no_method_error) do
        NoMethodError.new("Somethimes SEARCH responses come out undefined")
      end

      before do
        allow(client).to receive(:examine).
          with(ENCODED_FOLDER_NAME).and_raise(missing_mailbox_error)
      end

      it "returns an empty array" do
        expect(subject.uids).to eq([])
      end
    end

    context "when the UID search fails" do
      before do
        allow(client).to receive(:uid_search).and_raise(NoMethodError)
      end

      it "returns an empty array" do
        expect(subject.uids).to eq([])
      end
    end
  end

  describe "#fetch_multi" do
    let(:message_body) { instance_double(String, force_encoding: nil) }
    let(:attributes) { {"UID" => "uid", "BODY[]" => message_body, "other" => "xxx"} }
    let(:fetch_data_item) do
      instance_double(Net::IMAP::FetchData, attr: attributes)
    end

    before { allow(client).to receive(:uid_fetch) { [fetch_data_item] } }

    it "returns the uid and message" do
      expect(subject.fetch_multi([123])).to eq([{uid: "uid", body: message_body}])
    end

    context "when the server responds with nothing" do
      before { allow(client).to receive(:uid_fetch) { nil } }

      it "is nil" do
        expect(subject.fetch_multi([123])).to be_nil
      end
    end

    context "when the mailbox doesn't exist" do
      before do
        allow(client).to receive(:examine).
          with(ENCODED_FOLDER_NAME).and_raise(missing_mailbox_error)
      end

      it "is nil" do
        expect(subject.fetch_multi([123])).to be_nil
      end
    end

    context "when the first fetch_uid attempts fail with EOF" do
      before do
        outcomes = [-> { raise EOFError }, -> { [fetch_data_item] }]
        allow(client).to receive(:uid_fetch) { outcomes.shift.call }
      end

      it "retries" do
        subject.fetch_multi([123])

        expect(client).to have_received(:uid_fetch).twice
      end

      it "succeeds" do
        subject.fetch_multi([123])
      end
    end

    context "when the first fetch_uid attempts fail with Errno::ECONNRESET" do
      before do
        outcomes = [-> { raise Errno::ECONNRESET }, -> { [fetch_data_item] }]
        allow(client).to receive(:uid_fetch) { outcomes.shift.call }
      end

      it "retries" do
        subject.fetch_multi([123])

        expect(client).to have_received(:uid_fetch).twice
      end

      it "succeeds" do
        subject.fetch_multi([123])
      end
    end
  end

  describe "#folder" do
    it "is the name" do
      expect(subject.folder).to eq(FOLDER_NAME)
    end
  end

  describe "#exist?" do
    context "when the folder exists" do
      it "is true" do
        expect(subject.exist?).to be_truthy
      end
    end

    context "when the folder doesn't exist" do
      before do
        allow(client).to receive(:examine).
          with(ENCODED_FOLDER_NAME).and_raise(missing_mailbox_error)
      end

      it "is false" do
        expect(subject.exist?).to be_falsey
      end
    end
  end

  describe "#create" do
    context "when the folder exists" do
      it "is does not create the folder" do
        expect(client).to_not receive(:create)

        subject.create
      end
    end

    context "when the folder doesn't exist" do
      before do
        allow(client).to receive(:examine).
          with(ENCODED_FOLDER_NAME).and_raise(missing_mailbox_error)
      end

      it "creates the folder" do
        expect(client).to receive(:create)

        subject.create
      end

      it "encodes the folder name" do
        expect(client).to receive(:create).with(ENCODED_FOLDER_NAME)

        subject.create
      end
    end
  end

  describe "#uid_validity" do
    let(:responses) { {"UIDVALIDITY" => ["x", "uid validity"]} }

    it "is returned" do
      expect(subject.uid_validity).to eq("uid validity")
    end

    context "when the folder doesn't exist" do
      before do
        allow(client).to receive(:examine).
          with(ENCODED_FOLDER_NAME).and_raise(missing_mailbox_error)
      end

      it "raises an error" do
        expect do
          subject.uid_validity
        end.to raise_error(Imap::Backup::FolderNotFound)
      end
    end
  end

  describe "#append" do
    let(:message) do
      instance_double(
        Email::Mboxrd::Message,
        imap_body: "imap body",
        date: message_date
      )
    end
    let(:message_date) { Time.new(2010, 10, 10, 9, 15, 22, 0) }
    let(:append_response) do
      OpenStruct.new(data: OpenStruct.new(code: OpenStruct.new(data: "1 2")))
    end

    it "appends the message" do
      expect(client).to receive(:append)

      subject.append(message)
    end

    it "sets the date and time" do
      expect(client).to receive(:append).
        with(anything, anything, anything, message_date)

      subject.append(message)
    end

    it "returns the new uid" do
      expect(subject.append(message)).to eq(2)
    end

    it "set the new uid validity" do
      subject.append(message)

      expect(subject.uid_validity).to eq(1)
    end
  end

  describe "#clear" do
    before do
      subject.clear
    end

    it "uses select to have read-write access" do
      expect(client).to have_received(:select)
    end

    it "marks all emails as deleted" do
      expect(client).
        to have_received(:uid_store).with(uids.sort, "+FLAGS", [:Deleted])
    end

    it "deletes marked emails" do
      expect(client).to have_received(:expunge)
    end
  end
end

# rubocop:enable RSpec/PredicateMatcher
