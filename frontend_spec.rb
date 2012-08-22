# coding: utf-8

require './frontend'

describe AudioExam do
  before do
    @audioexam = AudioExam.new('test')
    @hp_id = 19
    @examdate = Time.now.strftime("%Y:%m:%d-%H:%M:%S")
    @audiometer = "AA-79S"
    @comment = "a_comment"
    @raw_audiosample = "7@/          /  080604  //   0   30 ,  10   35 ,  20   40 ,          ,  30   45 ,          ,  40   50 ,          ,  50   55 ,          ,  60   60 ,          , -10   55 ,  -5   55 ,          ,   0   55 ,          ,   5   55 ,          ,  10   55 ,          ,  15   55 ,  4>  4<,  4>  4<,  4>  4<,        ,  4>  4<,        ,  4>  4<,        ,  4>  4<,        ,  4>  4<,        ,  4>  4<,  4>  4<,        ,  4>  4<,        ,  4>  4<,        ,  4>  4<,        ,  4>  4<,/P"
    #  125 250 500  1k  2k  4k  8k
    #R   0  10  20  30  40  50  60
    #L  30  35  40  45  50  55  60
    @output_file = "./result.png"
    @bg_file = "./assets/background.png"
  end

  it "test mode/flight modeを使い分けられること" do
    @audioexam.mode.should == 'test'
    @audioexam.mode.should_not == 'flight'
    AudioExam.new.mode.should == 'flight'
    AudioExam.new.mode.should_not == 'test'
    AudioExam.new('wrong mode').mode.should_not == 'test'
  end

  context 'ID、検査値などが正しく与えられた時' do
    before do
      @audioexam.set_data(@hp_id, @examdate, @comment, @raw_audiosample)
    end

    it 'ID、検査値などがセットできること' do
      @audioexam.data[:hp_id].should == @hp_id
      @audioexam.data[:examdate].should == @examdate
      @audioexam.data[:audiometer].should == @audiometer
      @audioexam.data[:comment].should == @comment
      @audioexam.data[:datatype].should == "audiogram"
      @audioexam.data[:data].should == @raw_audiosample
    end

    it 'Audiogramが生成されること' do
      File::delete(@output_file) if File::exists?(@output_file)
      @audioexam.output
      File::exists?(@output_file).should be_true
    end

    it '生成されたAudiogramが白紙ではない=背景と異なっていること' do
      require 'digest/md5'
      File::delete(@output_file) if File::exists?(@output_file)
      @audioexam.output
      Digest::MD5.hexdigest(File.open(@output_file, 'rb').read).should_not ==\
        Digest::MD5.hexdigest(File.open(@bg_file, 'rb').read)
    end
  end

  it 'dataがtimeoutであった場合、timeout画像を表示できること' do
    pending '本当に必要かどうか'
  end

  it 'POST#direct_createの際のリクエスト用文字列を作れること' do
    @audioexam.set_data(@hp_id, @examdate, @comment, @raw_audiosample)
    message = @audioexam.request_body
    boundary = 'image_boundary'
    r = Regexp.new(".+#{boundary}.+form-data.+#{@hp_id}.+#{boundary}.+#{@examdate}.+#{boundary}.+#{@audiometer}.+#{boundary}.+#{@comment}.+#{boundary}.+audiogram.+#{boundary}.+#{@raw_audiosample}.+#{boundary}", Regexp::MULTILINE)
    message.should match r
  end
end

describe Pixbuf_msg do
  it "それぞれpixbufを用意できること" do
    pixbuf_msg = Pixbuf_msg.new
    pixbuf_msg.scan.should_not be_nil
    pixbuf_msg.recieve.should_not be_nil
    pixbuf_msg.timeout.should_not be_nil
  end
end

describe Markup_msg do
  it "それぞれmarkupされたメッセージを用意できること" do
    markup_msg = Markup_msg.new
    markup_msg.scan.should match /black/
    markup_msg.scan.should_not match /red/
    markup_msg.recieve.should match /black/
    markup_msg.recieve.should_not match /red/
    markup_msg.transmit.should match /black/
    markup_msg.transmit.should_not match /red/
    markup_msg.timeout.should match /red/
    markup_msg.timeout.should_not match /black/
    markup_msg.invalid_id.should match /red/
    markup_msg.invalid_id.should_not match /black/
    markup_msg.no_data.should match /red/
    markup_msg.no_data.should_not match /black/
  end
end

=begin
あたらしい送信の仕方

# coding: utf-8
require "net/http"
require "uri"

SERVER_URI = "http://127.0.0.1:3000/patients/direct_create/"

def send_data
  #   return if send_images.empty?
  uri = URI.parse(SERVER_URI)
  Net::HTTP.start(uri.host, uri.port) do |http|
    request = Net::HTTP::Post.new(uri.path)

    # header
    request["user-agent"] = "Ruby/#{RUBY_VERSION} MyHttpClient"
    request.set_content_type("multipart/form-data; boundary=image_boundary")
		
    # body, following multipart/form-data manner
    body = String.new
    body << "--image_boundary\r\n"
    body << "content-disposition: form-data; name=\"hp_id\";\r\n"
    body << "\r\n"
    body << "#{Valid_hp_id}\r\n"
    body << "--image_boundary\r\n"
    body << "content-disposition: form-data; name=\"examdate\";\r\n"
    body << "\r\n"
    body << "#{Examdate}\r\n"
    body << "--image_boundary\r\n"
    body << "content-disposition: form-data; name=\"audiometer\";\r\n"
    body << "\r\n"
    body << "#{Audiometer}\r\n"
    body << "--image_boundary\r\n"
    body << "content-disposition: form-data; name=\"comment\";\r\n"
    body << "\r\n"
    body << "#{Comment}\r\n"
    body << "--image_boundary\r\n"
    body << "content-disposition: form-data; name=\"data\";\r\n"
    body << "\r\n"
    body << "#{Raw_audiosample}\r\n"
    body << "--image_boundary--\r\n"

    request.body = body

    response = http.request(request)
p response
  end
end

send_data
=end
