module Imap::Backup
  describe Setup::ConnectionTester do
    describe "#test" do
      subject { described_class.new("foo") }

      let(:connection) do
        instance_double(Account::Connection, client: nil)
      end

      before do
        allow(Account::Connection).to receive(:new) { connection }
      end

      it "tries to connect" do
        expect(connection).to receive(:client)

        subject.test
      end

      describe "success" do
        it "returns success" do
          expect(subject.test).to match(/successful/)
        end
      end

      describe "failure" do
        before do
          allow(connection).to receive(:client).and_raise(error)
        end

        context "with no connection" do
          let(:error) do
            data = OpenStruct.new(text: "bar")
            response = OpenStruct.new(data: data)
            Net::IMAP::NoResponseError.new(response)
          end

          it "returns error" do
            expect(subject.test).to match(/no response/i)
          end
        end

        context "when caused by other errors" do
          let(:error) { "Error" }

          it "returns error" do
            expect(subject.test).to match(/unexpected error/i)
          end
        end
      end
    end
  end
end
