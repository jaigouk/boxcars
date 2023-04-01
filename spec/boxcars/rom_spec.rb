# frozen_string_literal: true

RSpec.describe Boxcars::Rom do
  let(:rom_container) { described_class.new.container }
  let(:database_url) { 'sqlite::memory' }

  let(:user_repo) { UserRepository.new(rom_container) }
  let(:comment_repo) { CommentRepository.new(rom_container) }
  let(:ticket_repo) { TicketRepository.new(rom_container) }
  let!(:john) { user_repo.create(name: "John") }
  let!(:sally) { user_repo.create(name: "Sally") }
  let!(:first_ticket) { ticket_repo.create(user_id: john.id, title: "First ticket", body: "This is the first ticket") }
  let!(:second_ticket) { ticket_repo.create(user_id: sally.id, title: "Second ticket", body: "This is the second ticket") }
  let!(:third_ticket) { ticket_repo.create(user_id: sally.id, title: "Third ticket", body: "This is the third ticket") }
  let!(:comment1) { comment_repo.create(user_id: john.id, ticket_id: first_ticket.id, content: "This is a comment") }
  let!(:comment2) { comment_repo.create(user_id: john.id, ticket_id: first_ticket.id, content: "This is johns second comment") }
  let!(:comment3) { comment_repo.create(user_id: sally.id, ticket_id: third_ticket.id, content: "This is another comment") }
  let!(:comment4) { comment_repo.create(user_id: sally.id, ticket_id: third_ticket.id, content: "This is yet another bingo comment") }

  before do
    allow(ENV).to receive(:fetch).with('DATABASE_URL', 'sqlite:///:memory:').and_return(database_url)
    allow(ENV).to receive(:fetch).with('LOG_GEN', false).and_return(false)
  end

  context "with sample helpdesk app all relations" do
    let(:boxcar) { described_class.new(database_url: database_url) }

    it "can count all tickets" do
      expect(boxcar.run("count of tickets?")).to eq(3)
    end

    it "can find the first ticket" do
      expect(boxcar.run("What is the first ticket?")).to include("First ticket")
    end

    it "can update the status of all open tickets to closed" do
      open_tickets_count = rom_container.relations[:tickets].where(status: "open").count
      expect(boxcar.run("update all open tickets to closed")).to eq(open_tickets_count)
      expect(rom_container.relations[:tickets].where(status: "closed").count).to eq(3)
    end

    it "can find all open tickets" do
      expect(boxcar.run("What are all open tickets?")).to include("First ticket", "Second ticket")
    end

    it "can count comments on the first ticket" do
      expect(boxcar.run("count of comments on the first ticket?")).to eq(2)
    end

    it "can find the content of the first comment on the first ticket" do
      expect(boxcar.run("What is the content of the first comment on the first ticket?")).to include("This is a comment")
    end

    it "can count all comments" do
      expect(boxcar.run("count of comments?")).to eq(4)
    end

    it "can find the content of all comments on the third ticket" do
      expect(boxcar.run("What are the contents of all comments on the third ticket?")).to include("This is another comment", "This is yet another bingo comment")
    end

    it "can execute multiple queries" do
      expect(boxcar.run("count of tickets?; count of comments?")).to eq([rom_container.relations[:tickets].count, rom_container.relations[:comments].count])
    end
  end

  context "with sample helpdesk app and filtered relations" do
    let(:boxcar) { described_class.new(models: [rom_container.relations[:tickets]], database_url: database_url) }

    it "can count all tickets" do
      expect(boxcar.run("count of tickets?")).to eq(3)
    end

    it "can find the first ticket" do
      expect(boxcar.run("What is the first ticket?")).to include("First ticket")
    end

    it "can update the status of all open tickets to closed" do
      open_tickets_count = rom_container.relations[:tickets].where(status: "open").count
      expect(boxcar.run("update all open tickets to closed")).to eq(open_tickets_count)
      expect(rom_container.relations[:tickets].where(status: "closed").count).to eq(3)
    end

    it "cannot count comments on the first ticket" do
      expect { boxcar.run("count of comments on the first ticket?") }.to raise_error(NameError)
    end

    it "cannot find the content of the first comment on the first ticket" do
      expect { boxcar.run("What is the content of the first comment on the first ticket?") }.to raise_error(NameError)
    end

    it "cannot count all comments" do
      expect { boxcar.run("count of comments?") }.to raise_error(NameError)
    end

    it "cannot find the content of all comments on the third ticket" do
      expect { boxcar.run("What are the contents of all comments on the third ticket?") }.to raise_error(NameError)
    end

    it "can execute multiple queries" do
      expect(boxcar.run("count of tickets?; count of comments?")).to eq([rom_container.relations[:tickets].count, nil])
    end
  end
end
