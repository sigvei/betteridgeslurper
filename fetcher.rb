require 'rss'
require 'open-uri'
require 'sqlite3'

SOURCES=File.readlines("sources.txt")
PATTERN=/\?/
DATABASE="database.sqlite3"

class Database
  SCHEMA = "CREATE TABLE IF NOT EXISTS posts (src varchar(255), guid varchar(255));"
  FIND = "SELECT COUNT(*) AS cnt FROM posts WHERE src=? AND guid=?;"
  INSERT = "INSERT INTO posts (src, guid) VALUES (?, ?);"

  def initialize(filename)
    self.db = SQLite3::Database.new(filename, type_translation: true)
    db.execute SCHEMA
    db.type_translation = true
  end

  def db
    @database
  end

  def db=(db)
    @database = db
  end

  def add(feed, item_guid)
    db.execute(INSERT, [feed, item_guid.to_s])
  end

  def contains?(feed, item_guid)
    rows = self.db.get_first_row(FIND, [feed, item_guid.to_s])
    return rows[0][0] > 0
  end
end

@db = Database.new(DATABASE)

@new = []
SOURCES.each do |source|
  open(source.chomp) do |rss|
    STDERR << "Parsing #{source}"
    feed = RSS::Parser.parse(rss, false)
    feed.items.select do |item|
      (item.title && item.title.match(PATTERN)) || 
        (item.description && item.description.match(PATTERN))
    end.each do |match|
      unless @db.contains?(feed.channel.title, match.guid)
        @new << [feed.channel.title, match]
        @db.add(feed.channel.title, match.guid)
      end
    end
  end
end

TEMPLATE = <<-EOF
%s:
%s

%s

%s

-----------------------------------------------------------------------
EOF

def fix_string(str)
  str.gsub("\n", " ").gsub("\r", " ").slice(0,45)
end

@new.each do |feed, item|
  puts TEMPLATE % [feed, item.title, fix_string(item.description), item.link]
end
