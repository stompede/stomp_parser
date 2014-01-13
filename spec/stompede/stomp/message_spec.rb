describe Stompede::Stomp::Message do
  describe "#to_str" do
    specify "message with command only" do
      message = Stompede::Stomp::Message.new("CONNECT", nil)
      message.to_str.should eq "CONNECT\n\n\x00"
    end

    specify "message with with headers" do
      message = Stompede::Stomp::Message.new("CONNECT", { "moo" => "cow", "boo" => "hoo" }, nil)
      message.to_str.should eq "CONNECT\nmoo:cow\nboo:hoo\n\n\x00"
    end

    specify "message with with body" do
      message = Stompede::Stomp::Message.new("CONNECT", "this is a body")
      message.to_str.should eq "CONNECT\n\nthis is a body\x00"
    end

    specify "message with escapeable characters in headers" do
      message = Stompede::Stomp::Message.new("CONNECT", { "k\\\n\r:" => "v\\\n\r:" }, nil)
      message.to_str.should eq "CONNECT\nk\\\\\\n\\r\\c:v\\\\\\n\\r\\c\n\n\x00"
    end

    specify "message with binary body" do
      message = Stompede::Stomp::Message.new("CONNECT", "\x00ab\x00")
      message.to_str.should eq "CONNECT\ncontent-length:4\n\n\x00ab\x00\x00"
    end
  end
end