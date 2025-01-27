require "json"
require "os"

# rubocop:disable RSpec/PredicateMatcher

module Imap::Backup
  describe Configuration do
    let(:directory) { "/base/path" }
    let(:file_path) { File.join(directory, "/config.json") }
    let(:file_exists) { true }
    let(:directory_exists) { true }
    let(:debug) { true }
    let(:configuration) { data.to_json }
    let(:data) { {debug: debug, accounts: accounts.map(&:to_h)} }
    let(:accounts) { [account1, account2] }
    let(:account1) { Account.new({username: "username1"}) }
    let(:account2) { Account.new({username: "username2"}) }

    before do
      stub_const(
        "Imap::Backup::Configuration::CONFIGURATION_DIRECTORY", directory
      )
      allow(File).to receive(:directory?).and_call_original
      allow(File).to receive(:directory?).with(directory) { directory_exists }
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(file_path) { file_exists }
      allow(Utils).
        to receive(:stat).with(directory) { 0o700 }
      allow(Utils).
        to receive(:stat).with(file_path) { 0o600 }
      allow(Utils).to receive(:check_permissions) { nil }
      allow(File).to receive(:read).and_call_original
      allow(File).to receive(:read).with(file_path) { configuration }
    end

    describe ".exist?" do
      [true, false].each do |exists|
        state = exists ? "exists" : "doesn't exist"
        context "when the file #{state}" do
          let(:file_exists) { exists }

          it "returns #{exists}" do
            expect(described_class.exist?).to eq(file_exists)
          end
        end
      end
    end

    describe "#path" do
      it "is the directory containing the configuration file" do
        expect(subject.path).to eq(directory)
      end
    end

    describe "#modified?" do
      context "with modified accounts" do
        before { subject.accounts[0].username = "changed" }

        it "is true" do
          expect(subject.modified?).to be_truthy
        end
      end

      context "with accounts flagged 'delete'" do
        before { subject.accounts[0].mark_for_deletion }

        it "is true" do
          expect(subject.modified?).to be_truthy
        end
      end

      context "without accounts flagged 'modified'" do
        it "is false" do
          expect(subject.modified?).to be_falsey
        end
      end
    end

    describe "#debug?" do
      context "when the debug flag is true" do
        it "is true" do
          expect(subject.debug?).to be_truthy
        end
      end

      context "when the debug flag is false" do
        let(:debug) { false }

        it "is false" do
          expect(subject.debug?).to be_falsey
        end
      end

      context "when the debug flag is missing" do
        let(:data) { {accounts: accounts} }

        it "is false" do
          expect(subject.debug?).to be_falsey
        end
      end

      context "when the debug flag is neither true nor false" do
        let(:debug) { "hi" }

        it "is false" do
          expect(subject.debug?).to be_falsey
        end
      end
    end

    describe "#debug=" do
      before { subject.debug = debug }

      context "when the supplied value is true" do
        it "sets the flag to true" do
          expect(subject.debug?).to be_truthy
        end
      end

      context "when the supplied value is false" do
        let(:debug) { false }

        it "sets the flag to false" do
          expect(subject.debug?).to be_falsey
        end
      end

      context "when the supplied value is neither true nor false" do
        let(:debug) { "ciao" }

        it "sets the flag to false" do
          expect(subject.debug?).to be_falsey
        end
      end
    end

    describe "#save" do
      subject { described_class.new }

      let(:directory_exists) { false }
      let(:file) { instance_double(File, write: nil) }

      before do
        allow(FileUtils).to receive(:mkdir)
        allow(FileUtils).to receive(:chmod)
        allow(File).to receive(:open).and_call_original
        allow(File).to receive(:open).with(file_path, "w").and_yield(file)
        allow(JSON).to receive(:pretty_generate) { "JSON output" }
      end

      it "creates the config directory" do
        expect(FileUtils).to receive(:mkdir).with(directory)

        subject.save
      end

      it "saves the configuration" do
        expect(file).to receive(:write).with("JSON output")

        subject.save
      end

      it "uses the Account#to_h method" do
        allow(subject.accounts[0]).to receive(:to_h) { "Account1" }
        allow(subject.accounts[1]).to receive(:to_h) { "Account2" }

        expect(JSON).to receive(:pretty_generate).
          with(hash_including({accounts: %w[Account1 Account2]}))

        subject.save
      end

      context "when accounts are to be deleted" do
        let(:accounts) do
          [
            {name: "keep_me"},
            {name: "delete_me", delete: true}
          ]
        end

        before do
          allow(subject.accounts[0]).to receive(:to_h) { "Account1" }
          allow(subject.accounts[1]).to receive(:to_h) { "Account2" }
          subject.accounts[0].mark_for_deletion
        end

        it "does not save them" do
          expect(JSON).to receive(:pretty_generate).
            with(hash_including({accounts: ["Account2"]}))

          subject.save
        end
      end

      context "when file permissions are too open" do
        context "when on UNIX" do
          before do
            allow(OS).to receive(:windows?) { false }
          end

          it "sets them to 0600" do
            expect(FileUtils).to receive(:chmod).with(0o600, file_path)

            subject.save
          end
        end
      end

      context "when the configuration file is missing" do
        let(:file_exists) { false }

        it "doesn't fail" do
          expect do
            subject.save
          end.to_not raise_error
        end
      end

      context "when on UNIX" do
        before do
          allow(OS).to receive(:windows?) { false }
        end

        context "when the config file permissions are too lax" do
          let(:file_exists) { true }

          before do
            allow(Utils).to receive(:check_permissions).
              with(file_path, 0o600).and_raise("Error")
          end

          it "fails" do
            expect do
              subject.save
            end.to raise_error(RuntimeError, "Error")
          end
        end
      end
    end
  end
end

# rubocop:enable RSpec/PredicateMatcher
