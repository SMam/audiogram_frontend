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
      return self.request_body
    end
  end
end

class Markup_msg
  def initialize
    @scan = make_markup("IDをバーコードまたはキーボードから入力してください\nscan Barcode or Input ID.", "black")
    @receive = make_markup("データ受信中\nReceiving data now...", "black")
    @transmit = make_markup("送信ボタンを押してください\nTransmit, please", "black")
    @timeout = make_markup("時間切れです 中止してやり直してください\nTimeout! Abort and retry please", "red")
    @invalid_id = make_markup("IDが間違っています。再入力してください\nInvalid ID. Scan or Input again", "red")
    @no_data = make_markup("有効なデータがありません。\nNo data", "red")
  end

  def make_markup(msg, color) # Pango Text Attribute Markup Language
    markup = "<span foreground=\"#{color}\" size=\"x-large\">#{msg}</span>"
  end

  def show(state)
    case state
    when "scan"
      @scan
    when "receive"
      @receive
    when "timeout"
      @timeout
    when "transmit"
      @transmit
    when "invalid_id"
      @invalid_id
    when "no_data"
      @no_data
    else
      nil
    end
  end
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
    @state = "scan" 
      # @state also can be "receive", "transmit", "timeout", "invalid_id", "no_data"
    @blank_png = Gdk::Pixbuf.new(Assets_location + "background.png")
    @markup_msg = Markup_msg.new
    deploy_wigets
    set_logics
    @test_mode = false
    @test_data = String.new
    @http_request = nil
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
    @image = Gtk::Image.new(@blank_png)

    # message area
    @msg_label = Gtk::Label.new
    @msg_label.set_markup(@markup_msg.show(@state))

    # comment area
    # comment_retry.active? => true or false
    @comment_retry = Gtk::CheckButton.new(label = "再検査 RETRY")
    @comment_masking = Gtk::CheckButton.new(label = "マスキング適用 MASK_")
    @comment_after_patch = Gtk::CheckButton.new(label = "パッチ後 PATCH")
    @comment_after_med = Gtk::CheckButton.new(label = "投薬後 MEDIC")
    @comment_other_check = Gtk::CheckButton.new(label = "その他 OTHER: write here ----->")
    @comment_other_entry = Gtk::Entry.new
    @comment_other_entry.max_length = 100
    comment_other_box = Gtk::HBox.new(false,0)
    comment_other_box.pack_start(@comment_other_check, true, true, 0)
    comment_other_box.pack_start(@comment_other_entry, true, true, 0)
    comment_box = Gtk::VBox.new(false,0)
    comment_box.pack_start(@comment_retry, true, true, 0)
    comment_box.pack_start(@comment_masking, true, true, 0)
    comment_box.pack_start(@comment_after_patch, true, true, 0)
    comment_box.pack_start(@comment_after_med, true, true, 0)
    comment_box.pack_start(comment_other_box, true, true, 0)

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

  def set_logics
  ## button logics
    @button_id_entry.signal_connect("clicked") do
      @id_entry.text = id_entry.text.delete("^0-9") # remove non-number
      if valid_id?(@id_entry.text) and id_entry.text != ""
        @state = "receive"
        @msg_label.set_markup(@markup_msg.show(@state))
	if @test_mode
	  @audioexam = AudioExam.new('test')
	  sent_data = @test_data
        else
	  @audioexam = AudioExam.new('flight')
#          sent_data = receive_data
          sent_data = Rs232c.new.get_data_from_audiometer  # from 'com_RS232C_AA79S.rb'
	end
        if sent_data == "Timeout"
          @state = "timeout"
          @msg_label.set_markup(@markup_msg.show(@state))
        else
          @audioexam.set_data(@id_entry.text, Time.now.strftime("%Y:%m:%d-%H:%M:%S"),\
            "comment", sent_data)
          begin
            @audioexam.output
          rescue
            @state = "no_data"
            @msg_label.set_markup(markup_msg.show(@state))
	  else
            @image.pixbuf = Gdk::Pixbuf.new("./result.png")
            @state = "transmit"
            @msg_label.set_markup(markup_msg.show(@state))
	  end
          system("mpg123 -q " + Assets_location + "se.mp3")
        end
      else
        @state = "invalid_id"
        @msg_label.set_markup(@markup_msg.show(@state))
      end
    end

    @button_abort.signal_connect("clicked") do
      reset_properties
    end

    @button_transmit.signal_connect("clicked") do
      # @stateがtransmitの時は送る、それ以外 scan, receiveなどの時は何もしない
      case @state
      when "transmit"
        if @audioexam.data[:id] != ''
          comment = ""
          comment += "RETRY_" if @comment_retry.active?
          comment += "MASK_"  if @comment_masking.active?
          comment += "PATCH_" if @comment_after_patch.active?
          comment += "MED_"   if @comment_after_med.active?
          comment += "OTHER:#{comment_other_entry.text}_"\
	    if (@comment_other_check.active? or /\S+/ =~ @comment_other_entry.text)
          @audioexam.data[:comment] = comment
          @http_request = @audioexam.transmit
          reset_properties
        else
          @state = "no_data"
          msg_label.set_markup(markup_msg.show(@state))
        end
      end
    end

    @button_quit.signal_connect("clicked") do
      Gtk.main_quit
    end
  end

  def reset_properties
    @id_entry.text = ""
    @image = Gtk::Image.new(@blank_png)
    @state = "scan"
    @msg_label.set_markup(@markup_msg.show(@state))
    @comment_retry.active = false
    @comment_masking.active = false
    @comment_after_patch.active = false
    @comment_after_med.active = false
    @comment_other_check.active = false
    @comment_other_entry.text = ""
    @audioexam = AudioExam.new
    @win.set_focus(@id_entry)
  end

  def show
    @win.show_all
    Gtk.main
  end

  attr_accessor :id_entry, :button_id_entry, :markup_msg, :image, :state, :audioexam,\
                :test_mode, :test_data, :button_abort, :button_transmit,\
                :comment_retry, :comment_masking, :comment_after_patch,\
                :comment_after_med, :comment_other_check, :comment_other_entry,\
		:http_request
end

# -----
if ($0 == __FILE__)
  ew = Exam_window.new
  ew.show
end
