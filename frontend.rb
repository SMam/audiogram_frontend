#! /usr/local/bin/ruby
# -*- coding: utf-8 -*-

require 'gtk2'
require 'net/http'
require './id_validation'
require './com_RS232C_AA79S'
require './audio_class'

SERVER_IP = '127.0.0.1' #SERVER_IP = '172.16.41.20' #SERVER_IP = '192.168.1.6'
SERVER_URI = "http://#{SERVER_IP}:3000/patients/direct_create/"
AUDIOMETER = "AA-79S"

TEST_MODE = true

if defined? Rails
  Assets_location = "lib/assets/"
else
  Assets_location = "./assets/"
end

class AudioExam
  def initialize(* mode)
    case mode[0]
    when 'test','Test','TEST'
      @mode = 'test'
    else
      @mode = 'flight'
    end
    @data = {:hp_id => '', :examdate => '', :data => '', :comment => ''}
  end

  attr_accessor :mode, :data

  def set_data(hp_id, examdate, comment, data)
    @data[:hp_id] = hp_id
    @data[:examdate] = examdate
    @data[:audiometer] = AUDIOMETER
    @data[:datatype] = "audiogram"
    @data[:data] = data
    @data[:comment] = comment
  end

  def output
    a = Audio.new( Audiodata.new("raw", @data[:data]))
    a.draw("./result.png")
  end

  def request_body
    body = String.new
    body << "--image_boundary\r\ncontent-disposition: form-data; "
    body << "name=\"hp_id\";\r\n\r\n#{@data[:hp_id]}\r\n"
    body << "--image_boundary\r\ncontent-disposition: form-data; "
    body << "name=\"examdate\";\r\n\r\n#{@data[:examdate]}\r\n"
    body << "--image_boundary\r\ncontent-disposition: form-data; "
    body << "name=\"audiometer\";\r\n\r\n#{@data[:audiometer]}\r\n"
    body << "--image_boundary\r\ncontent-disposition: form-data; "
    body << "name=\"comment\";\r\n\r\n#{@data[:comment]}\r\n"
    body << "--image_boundary\r\ncontent-disposition: form-data; "
    body << "name=\"datatype\";\r\n\r\naudiogram\r\n"
    body << "--image_boundary\r\ncontent-disposition: form-data; "
    body << "name=\"data\";\r\n\r\n#{@data[:data]}\r\n"
    body << "--image_boundary--\r\n"
    return body
  end

  def transmit
    case mode
    when 'flight'
      uri = URI.parse(SERVER_URI)
      Net::HTTP.start(uri.host, uri.port) do |http|
        request = Net::HTTP::Post.new(uri.path)
        # header
        request["user-agent"] = "Ruby/#{RUBY_VERSION} MyHttpClient"
        request.set_content_type("multipart/form-data; boundary=image_boundary")
	# body, following multipart/form-data manner
	request.body = self.request_body
        response = http.request(request)
        puts response
      end
    when 'test'
      puts 'On the test mode, no request is POST.\n ---'
      puts self.request_body
    end
  end
end

class Pixbuf_msg
  def initialize
    @scan = Gdk::Pixbuf.new(Assets_location + "msg_scan.jpg")
    @recieve = Gdk::Pixbuf.new(Assets_location + "msg_recieve.jpg")
    @timeout = Gdk::Pixbuf.new(Assets_location + "msg_timeout.jpg")
  end

  attr_reader :scan, :recieve, :timeout
end

class Markup_msg
  def initialize
    @scan = make_markup("IDをバーコードまたはキーボードから入力してください\nscan Barcode or Input ID.", "black")
    @recieve = make_markup("データ受信中\nRecieving data now...", "black")
    @transmit = make_markup("送信ボタンを押してください\nTransmit, please", "black")
    @timeout = make_markup("時間切れです 中止してやり直してください\nTimeout! Abort and retry please", "red")
    @invalid_id = make_markup("IDが間違っています。再入力してください\nInvalid ID. Scan or Input again", "red")
    @no_data = make_markup("有効なデータがありません。\nNo data", "red")
  end

  def make_markup(msg, color) # Pango Text Attribute Markup Language
    markup = "<span foreground=\"#{color}\" size=\"x-large\">#{msg}</span>"
  end

  attr_reader :scan, :recieve, :transmit, :timeout, :invalid_id, :no_data
end

class Exam_window
  def initialize
    @win = Gtk::Window.new
    @win.border_width = 5
    @win.signal_connect('delete_event') do
      Gtk.main_quit
      false
    end
    @win.signal_connect("destroy") { Gtk.main_quit }
    @pixbuf_msg = Pixbuf_msg.new
    @markup_msg = Markup_msg.new
    deploy_wigets

  end

  def deploy_wigets
    # ID entry area
    id_label = Gtk::Label.new("ID: ")
    @id_entry = Gtk::Entry.new
    @id_entry.max_length = 20
    @id_entry.text = ""
    @button_id_entry = Gtk::Button.new("Enter")
    id_box = Gtk::HBox.new(false, 0)
    id_box.pack_start(id_label, true, true, 0)
    id_box.pack_start(@id_entry, true, true, 0)
    id_box.pack_start(@button_id_entry, true, true, 0)

    # audiogram appearance
    @image = Gtk::Image.new(@pixbuf_msg.scan)

    # message area
    @msg_label = Gtk::Label.new #(text_msg_scan)
    @msg_label.set_markup(@markup_msg.scan)

    # comment area
    # comment_retry.active? => true or false
    @comment_retry = Gtk::CheckButton.new(label = "再検査 RETRY")
    @comment_masking = Gtk::CheckButton.new(label = "マスキング適用 MASK_")
    @comment_after_patch = Gtk::CheckButton.new(label = "パッチ後 PATCH")
    @comment_after_med = Gtk::CheckButton.new(label = "投薬後 MEDIC")
    @comment_other_check = Gtk::CheckButton.new(label = "その他 OTHER: write here ----->")
    @comment_other_entry = Gtk::Entry.new
    @comment_other_entry.max_length = 100
    @comment_other_box = Gtk::HBox.new(false,0)
    @comment_other_box.pack_start(@comment_other_check, true, true, 0)
    @comment_other_box.pack_start(@comment_other_entry, true, true, 0)
    comment_box = Gtk::VBox.new(false,0)
    comment_box.pack_start(@comment_retry, true, true, 0)
    comment_box.pack_start(@comment_masking, true, true, 0)
    comment_box.pack_start(@comment_after_patch, true, true, 0)
    comment_box.pack_start(@comment_after_med, true, true, 0)
    comment_box.pack_start(@comment_other_box, true, true, 0)

    # button area
    @button_abort = Gtk::Button.new("中止 abort")
    @button_transmit = Gtk::Button.new("送信 Transmit")
    @button_quit = Gtk::Button.new("終了 Quit")
    button_box = Gtk::HBox.new(false, 0)
    button_box.pack_start(@button_abort, true, true, 0)
    button_box.pack_start(@button_transmit, true, true, 0)
    button_box.pack_start(@button_quit, true, true, 0)

    # packing box
    pack_box1 = Gtk::VBox.new(false, 0)
    pack_box1.pack_start(id_box, true, true, 0)
    pack_box1.pack_start(Gtk::HSeparator.new, true, true, 0)
    pack_box1.pack_start(@msg_label, true, true, 0)
    pack_box1.pack_start(Gtk::HSeparator.new, true, true, 0)
    pack_box1.pack_start(comment_box, true, true, 0)
    pack_box1.pack_start(button_box, true, true, 0)

    pack_box = Gtk::HBox.new(false, 0)
    pack_box.pack_start(@image, true, true, 0)
    pack_box.pack_start(pack_box1, true, true, 0)

    # @button_id_entry.can_default = true # Casting spells to make default widget
    # @button_id_entry.grab_default       # [Enter] key activates this widget

    @win.add(pack_box)
  end

=begin
test code
    @label = Gtk::Label.new("             ")
    @button = Gtk::Button.new("Hello")
    @button.signal_connect("clicked") {
    @label.text = "Hello, world." }
    @vbox = Gtk::VBox.new
    @vbox.pack_start(@label)
    @vbox.pack_start(@button)
    @window = Gtk::Window.new
    @window.signal_connect("destroy") {
      Gtk.main_quit }
    @window.add(@vbox)
  end

  attr_accessor :label, :button
=end

  def show
    @win.show_all
    Gtk.main
  end


end

# -----

if ($0 == __FILE__)
  ew = Exam_window.new
  ew.show
end



=begin



## button logics
button_id_entry.signal_connect("clicked") do
  case exam.state
  when 0
    id_entry.text = id_entry.text.delete("^0-9") # remove non-number
    if valid_id?(id_entry.text) and id_entry.text != ""
      image.pixbuf = pixbuf_msg.recieve
      msg_label.set_markup(markup_msg.recieve)
      exam.state = 1
      sent_data = recieve_data
      if sent_data == "Timeout"
        image.pixbuf = pixbuf_msg.timeout
        msg_label.set_markup(markup_msg.timeout)
      else
        exam.set_data(id_entry.text, Time.now.strftime("%Y:%m:%d-%H:%M:%S"),\
	  sent_data, '')
        # Time.now.strftime("%Y:%m:%d-%H:%M:%S") は 2008:09:27-12:50:00 形式
        system("mpg123 -q " + Assets_location + "se.mp3")
        image.pixbuf = Gdk::Pixbuf.new("./result.png")
        msg_label.set_markup(markup_msg.transmit)
        exam.state = 2
      end
    else
      puts "invalid"
      msg_label.set_markup(markup_msg.invalid_id)
    end
  end
end

#=begin
def new_exam
  id_entry.text = ""
  image.pixbuf = pixbuf_msg.scan
  msg_label.set_markup(markup_msg.scan)
  comment_retry.active = false
  comment_masking.active = false
  comment_after_patch.active = false
  comment_after_med.active = false
  comment_other_check.active = false
  comment_other_entry.text = ""
  exam = AudioExam.new
  window.set_focus(id_entry)
end
#=end

button_abort.signal_connect("clicked") do
#  case exam.state
#  when 2 #3
    id_entry.text = ""
    image.pixbuf = pixbuf_msg.scan
    msg_label.set_markup(markup_msg.scan)
    comment_retry.active = false
    comment_masking.active = false
    comment_after_patch.active = false
    comment_after_med.active = false
    comment_other_check.active = false
    comment_other_entry.text = ""
    exam = AudioExam.new
    window.set_focus(id_entry)
#  end
end

button_transmit.signal_connect("clicked") do
  case exam.state
  when 2
    if exam.data[:id] != ''
      comment = ""
      comment += "RETRY_" if comment_retry.active?
      comment += "MASK_"  if comment_masking.active?
      comment += "PATCH_" if comment_after_patch.active?
      comment += "MED_"   if comment_after_med.active?
      comment += "OTHER:#{comment_other_entry.text}_" if (comment_other_check.active? or /\S+/ =~ comment_other_entry.text)
      exam.data[:comment] = comment
      exam.transmit
#      exam.state = 3

      id_entry.text = ""
      image.pixbuf = pixbuf_msg.scan
      msg_label.set_markup(markup_msg.scan)
      comment_retry.active = false
      comment_masking.active = false
      comment_after_patch.active = false
      comment_after_med.active = false
      comment_other_check.active = false
      comment_other_entry.text = ""
      exam = AudioExam.new
      window.set_focus(id_entry)
    else
      msg_label.set_markup(markup_msg.no_data)
    end
  end
end

button_quit.signal_connect("clicked") do
  Gtk.main_quit
end

# ID enterance trigger : write data recieving procedure here
def recieve_data
  # actual code start
  if not TEST_MODE
    raw_data = Rs232c.new.get_data_from_audiometer
  else
  # dummy code start
    datafile = "sample_data/data_with_mask.dat"
    raw_data = String.new
    File.open(datafile, "r") do |f|
      raw_data = f.read
    end
  end

  if raw_data == "Timeout"
    return "Timeout"
  else
    r = Audiodata.new("raw", raw_data)
    a = Audio.new(r)
    a.draw
    a.output("./result.ppm")
    system("convert ./result.ppm ./result.png")   # convert with ImageMagick
    
    return raw_data
  end
end


=end
