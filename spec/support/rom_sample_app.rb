require 'sqlite3'
require 'rom'
require 'rom-sql'
require 'rom-repository'
require 'sequel'

# Set up ROM relations
class Users < ROM::Relation[:sql]
  schema(:users, infer: true) do
    associations do
      has_many :tickets
      has_many :comments
    end
  end
end

class Comments < ROM::Relation[:sql]
  schema(:comments, infer: true) do
    associations do
      belongs_to :user
      belongs_to :ticket
    end
  end
end

class Tickets < ROM::Relation[:sql]
  schema(:tickets, infer: true) do
    associations do
      belongs_to :user
      has_many :comments
    end
  end
end

# Set up a database that resides in RAM
def rom_sample_app_config
  rom_config = ROM::Configuration.new(:sql, 'sqlite::memory:')

  # Set up database tables and columns
  rom_config.gateways[:default].connection.create_table :users do
    primary_key :id
    column :name, String
    column :created_at, DateTime
    column :updated_at, DateTime
  end

  rom_config.gateways[:default].connection.create_table :comments do
    primary_key :id
    column :content, String
    column :user_id, Integer, index: true
    column :ticket_id, Integer, index: true
    column :created_at, DateTime
    column :updated_at, DateTime
  end

  rom_config.gateways[:default].connection.create_table :tickets do
    primary_key :id
    column :title, String
    column :user_id, Integer
    column :status, Integer, default: 0
    column :body, String
    column :created_at, DateTime
    column :updated_at, DateTime
  end

  # Register relations with ROM
  rom_config.register_relation(Users)
  rom_config.register_relation(Comments)
  rom_config.register_relation(Tickets)

  rom_config
end

# Set up ROM container
rom_container = ROM.container(rom_sample_app_config)

# Set up ROM repositories
class UserRepository < ROM::Repository[:users]
  commands :create

  def find_by_name(name)
    users.where(name: name).one
  end
end

class CommentRepository < ROM::Repository[:comments]
  commands :create
end

class TicketRepository < ROM::Repository[:tickets]
  commands :create
end

# Initialize repositories
user_repo = UserRepository.new(rom_container)
comment_repo = CommentRepository.new(rom_container)
ticket_repo = TicketRepository.new(rom_container)

# Add some data
john = user_repo.create(name: "John")
sally = user_repo.create(name: "Sally")
first_ticket = ticket_repo.create(user_id: john.id, title: "First ticket", body: "This is the first ticket")
second_ticket = ticket_repo.create(user_id: sally.id, title: "Second ticket", body: "This is the second ticket")
third_ticket = ticket_repo.create(user_id: sally.id, title: "Third ticket", body: "This is the third ticket")

comment_repo.create(user_id: john.id, ticket_id: first_ticket.id, content: "This is a comment")
comment_repo.create(user_id: john.id, ticket_id: first_ticket.id, content: "This is johns second comment")
comment_repo.create(user_id: sally.id, ticket_id: third_ticket.id, content: "This is another comment")
comment_repo.create(user_id: sally.id, ticket_id: third_ticket.id, content: "This is yet another bingo comment")

