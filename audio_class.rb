#!/usr/local/bin/ruby
#  Class Audio: 聴検データ取扱い用クラス
#  Copyright 2007-2009 S Mamiya <MamiyaShn@gmail.com>
#  0.20091107
#  0.20120519 : chunky_PNGのgemを使用、ruby1.9対応

require 'chunky_png'
require 'AA79S.rb'

RAILS_ROOT = ".." if not defined? RAILS_ROOT

#Image_parts_location = RAILS_ROOT+"/lib/assets/" # !!! 必要に応じて変更を !!!
#Image_parts_location = "./assets/" # とりあえず
Image_parts_location = "lib/assets/" # とりあえず

# railsの場合，directoryの相対表示の起点は rails/audiserv であるようだ
Overdraw_times = 2  # 重ね書きの回数．まずは2回，つまり1回前の検査までとする

class Bitmap
  RED =        0xff0000ff #[255,0,0]
  BLUE =       0x0000ffff #[0,0,255]
  RED_PRE0 =   0xff1e1eff #[255,30,30]
  RED_PRE1 =   0xff5a5aff #[255,90,90]
  BLUE_PRE0 =  0x1e1effff #[30,30,255]
  BLUE_PRE1 =  0x5a5affff #[90,90,255]
  BLACK =      0x000000ff #[0,0,0]
  BLACK_PRE0 = 0x1e1e1eff #[30,30,30]
  BLACK_PRE1 = 0x5a5a5aff #[90,90,90]
  WHITE =      0xffffffff #[255,255,255]
  GRAY =       0xaaaaaaff #[170,170,170]

  CIRCLE_PTN = [[-5,-2],[-5,-1],[-5,0],[-5,1],[-5,2],[-4,-3],[-4,3],\
    [-3,-4],[-3,4],[-2,-5],[-2,5],[-1,-5],[-1,5],[0,-5],[0,5],[1,-5],[1,5],\
    [2,-5],[2,5],[3,-4],[3,4],[4,-3],[4,3],[5,-2],[5,-1],[5,0],[5,1],[5,2]]
  CROSS_PTN = [[-5,-5],[-5,5],[-4,-4],[-4,4],[-3,-3],[-3,3],[-2,-2],[-2,2],\
    [-1,-1],[-1,1],[0,0],[1,-1],[1,1],[2,-2],[2,2],[3,-3],[3,3],[4,-4],[4,4],\
    [5,-5],[5,5]]
  R_BRA_PTN = [[-8,-5],[-8,-4],[-8,-3],[-8,-2],[-8,-1],[-8,0],[-8,1],[-8,2],\
    [-8,3],[-8,4],[-8,5],[-7,-5],[-7,5],[-6,-5],[-6,5]]
  L_BRA_PTN = [[8,-5],[8,-4],[8,-3],[8,-2],[8,-1],[8,0],[8,1],[8,2],[8,3],\
    [8,4],[8,5],[7,-5],[7,5],[6,-5],[6,5]]
  R_SCALEOUT_PTN = [[-3,12],[-4,13],[-5,6],[-5,7],[-5,8],[-5,9],\
    [-5,10],[-5,11],[-5,12],[-5,13],[-5,14],[-6,13],[-7,12]]
  L_SCALEOUT_PTN = [[3,12],[4,13],[5,6],[5,7],[5,8],[5,9],\
    [5,10],[5,11],[5,12],[5,13],[5,14],[6,13],[7,12]]
  SYMBOL_PTN = {:circle => CIRCLE_PTN, :cross => CROSS_PTN, :r_bracket => R_BRA_PTN,\
        :l_bracket => L_BRA_PTN, :r_scaleout => R_SCALEOUT_PTN, :l_scaleout => L_SCALEOUT_PTN}

  def initialize
    @png = ChunkyPNG::Image.new(400,400,WHITE)
  end

  def point(x,y,rgb)
    @png.set_pixel(x,y,rgb)
  end

  def swap(a,b)
    return b,a
  end

  def line(x1,y1,x2,y2,rgb,dotted)
    # Bresenhamアルゴリズムを用いた自力描画から変更
    if x1 > x2  # x2がx1以上であることを保証
      x1, x2 = swap(x1,x2)
      y1, y2 = swap(y1,y2)
    end
    sign_modifier = (y1 < y2)? 1 : -1 # yが減少していく時(右上がり)の符号補正
    case dotted
    when "line"
      @png.line(x1,y1,x2,y2,rgb)
    when "dot"
      dx = x2 - x1
      dy = y2 - y1
      dot_length = 4
      step = (Math::sqrt ( dx * dx + dy * dy )) / dot_length
      sx = (dx / step).round
      sy = (dy / step).round
      c = rgb
      x_line_end = y_line_end = false
      x_to = x1
      y_to = y1

      until x_line_end && y_line_end do
        x_from = x_to
        y_from = y_to
        if (x_to = x_from+sx) > x2  # x_from + sx が x_to を越えないように
          x_to = x2
          x_line_end = true
        end
        if (y_to = y_from+sy)*sign_modifier > y2*sign_modifier 
	                            # y_from + sy が y_to を越えないように(符号補正つき)
          y_to = y2
          y_line_end = true
        end
        @png.line(x_from,y_from,x_to,y_to,c)
        c = (c == WHITE)? rgb: WHITE
      end  
    end
  end

  def put_symbol(symbol, x, y, rgb) # symbol is Symbol, like :circle
    xr = x.round
    yr = y.round
    SYMBOL_PTN[symbol].each do |xy|
      point(xr+xy[0],yr+xy[1],rgb)
    end
  end

  def output(filename)
    @png.save(filename, :fast_rgba)
  end
end

#----------------------------------------#
class Background_bitmap < Bitmap
  def initialize
    if File.exist?(Image_parts_location+"background.png")
      @png = ChunkyPNG::Image.from_file(Image_parts_location+"background.png")
    else
      @png = ChunkyPNG::Image.new(400,400,WHITE)
      prepare_font
      draw_lines
      add_fonts
      @png.save(Image_parts_location+"background.png", :fast_rgba)
    end
  end

  def prepare_font
    font_name = ["0","1","2","3","4","5","6","7","8","9","k","Hz","dB","minus"]
    @font = Hash.new
    font_name.each do |f|
      @font[f] = Array.new
      @font[f] << ChunkyPNG::Image.from_file(Image_parts_location+"#{f}.png")
      case f
      when "Hz","dB"
        @font[f] << 2  # 文字幅の情報
      else
        @font[f] << 1
      end
    end
  end

  def draw_lines               # audiogramの縦横の線を引いている
    y1=30
    y2=348
    line(50,y1,50,y2,GRAY,"line")
    for x in 0..6
      x1=70+x*45
      line(x1,y1,x1,y2,GRAY,"line")
    end
    line(360,y1,360,y2,GRAY,"line")
    x1=50
    x2=360
    line(x1,30,x2,30,GRAY,"line")
    line(x1,45,x2,45,GRAY,"line")
    line(x1,69,x2,69,BLACK,"line")
    for y in 0..10
      y1=93+y*24
      line(x1,y1,x2,y1,GRAY,"line")
    end
    line(x1,348,x2,348,GRAY,"line")
  end

  def add_fonts
    # add vertical scale
    for i in -1..11
      x = 15
      hear_level = (i * 10).to_s
      y = 69 + i *24 -7
      x += (3 - hear_level.length) * 8
      hear_level.each_byte do |c|
        if c == 45                  # if character is "-"
          put_font(x, y, "minus")
        else
          put_font(x, y, "%c" % c)
        end
        x += 8
      end
    end
    put_font(23, 15, "dB")

    # add holizontal scale
    cycle = ["125","250","500","1k","2k","4k","8k"]
    for i in 0..6
      y = 358
      x = 70 + i * 45 - cycle[i].length * 4 # 8px for each char / 2
      cycle[i].each_byte do |c|
        put_font(x, y, "%c" % c)
        x += 8
      end
    end
    put_font(360, 358, "Hz")
  end

  def put_font(x1,y1,fontname)
    return if not @font[fontname]
    dx = @font[fontname][1] * 10
    dy = 15
    @png.compose!(@font[fontname][0],x1,y1)
  end
end

#----------------------------------------#
#class Audio < Bitmap
class Audio < Background_bitmap
  X_pos = [70,115,160,205,250,295,340]   # 各周波数別の横座標

  def initialize(audiodata)              # 引数はFormatted_data のインスタンス
    @audiodata = audiodata
    @air_rt  = @audiodata.extract[:ra]
    @air_lt  = @audiodata.extract[:la]
    @bone_rt = @audiodata.extract[:rb]
    @bone_lt = @audiodata.extract[:lb]
    super()
  end

  def put_rawdata
    return @audiodata.put_rawdata
  end

  def mean4          # 4分法
    if @air_rt[:data][2] and @air_rt[:data][3] and @air_rt[:data][4]
      mean4_rt = (@air_rt[:data][2] + @air_rt[:data][3] * 2 + @air_rt[:data][4]) /4
    else
      mean4_rt = -100.0
    end
    if @air_lt[:data][2] and @air_lt[:data][3] and @air_lt[:data][4]
      mean4_lt = (@air_lt[:data][2] + @air_lt[:data][3] * 2 + @air_lt[:data][4]) /4
    else
      mean4_lt = -100.0
    end
    mean4_bs = {:rt => mean4_rt, :lt => mean4_lt}
  end

  def reg_mean4          # 正規化4分法: scaleout は 105dB に
    if @air_rt[:data][2] and @air_rt[:data][3] and @air_rt[:data][4]
      r = {:data => @air_rt[:data], :scaleout => @air_rt[:scaleout]}
      for i in 2..4
        if r[:scaleout][i] or r[:data][i] > 100.0
          r[:data][i] = 105.0
        end
      end
      rmean4_rt = (r[:data][2] + r[:data][3] * 2 + r[:data][4]) /4
    else
      rmean4_rt = -100.0
    end
    if @air_lt[:data][2] and @air_lt[:data][3] and @air_lt[:data][4]
      l = {:data => @air_lt[:data], :scaleout => @air_lt[:scaleout]}
      for i in 2..4
        if l[:scaleout][i] or l[:data][i] > 100.0
          l[:data][i] = 105.0
        end
      end
      rmean4_lt = (l[:data][2] + l[:data][3] * 2 + l[:data][4]) /4
    else
      rmean4_lt = -100.0
    end
    rmean4_bs = {:rt => rmean4_rt, :lt => rmean4_lt}
  end


  def mean3          # 3分法
    if @air_rt[:data][2] and @air_rt[:data][3] and @air_rt[:data][4]
      mean3_rt = (@air_rt[:data][2] + @air_rt[:data][3] + @air_rt[:data][4]) /3
    else
      mean3_rt = -100.0
    end
    if @air_lt[:data][2] and @air_lt[:data][3] and @air_lt[:data][4]
      mean3_lt = (@air_lt[:data][2] + @air_lt[:data][3] + @air_lt[:data][4]) /3
    else
      mean3_lt = -100.0
    end
    mean3_bs = {:rt => mean3_rt, :lt => mean3_lt}
  end

  def mean6          # 6分法
    if @air_rt[:data][2] and @air_rt[:data][3] and @air_rt[:data][4] and @air_rt[:data][5]
      mean6_rt = (@air_rt[:data][2] + @air_rt[:data][3] * 2 + @air_rt[:data][4] * 2 + \
                  @air_rt[:data][5] ) /6
    else
      mean6_rt = -100.0
    end
    if @air_lt[:data][2] and @air_lt[:data][3] and @air_lt[:data][4] and @air_lt[:data][5]
      mean6_lt = (@air_lt[:data][2] + @air_lt[:data][3] * 2 + @air_lt[:data][4] * 2 + \
                  @air_lt[:data][5] ) /6
    else
      mean6_lt = -100.0
    end
    mean6_bs = {:rt => mean6_rt, :lt => mean6_lt}
  end

  def draw_sub(audiodata, timing)
    case timing  # timingは重ね書き用の引数で検査の時期がもっとも古いものは
                 # pre0，やや新しいものは pre1とする
    when "pre0"
      rt_color = RED_PRE0
      lt_color = BLUE_PRE0
      bc_color = BLACK_PRE0
    when "pre1"
      rt_color = RED_PRE1
      lt_color = BLUE_PRE1
      bc_color = BLACK_PRE1
    else
      rt_color = RED
      lt_color = BLUE
      bc_color = BLACK    
    end
    scaleout = audiodata[:scaleout]
    threshold = audiodata[:data]
    for i in 0..6
      if threshold[i]   # threshold[i] が nilの時は plot処理を skipする
        threshold[i] = threshold[i] + 0.0
        case audiodata[:side]
        when "Rt"
          case audiodata[:mode]
          when "Air"
            put_symbol(:circle, X_pos[i], threshold[i] / 10 * 24 + 69, rt_color)
            if scaleout[i]
              put_symbol(:r_scaleout, X_pos[i], threshold[i] / 10 * 24 + 69, rt_color)
            end
          when "Bone"
            put_symbol(:r_bracket, X_pos[i], threshold[i] / 10 * 24 + 69, bc_color)
            if scaleout[i]
              put_symbol(:r_scaleout, X_pos[i], threshold[i] / 10 * 24 + 69, bc_color)
            end
          end
        when "Lt"
          case audiodata[:mode]
          when "Air"
            put_symbol(:cross, X_pos[i], threshold[i] / 10 * 24 + 69, lt_color)
            if scaleout[i]
              put_symbol(:l_scaleout, X_pos[i], threshold[i] / 10 * 24 + 69, lt_color)
            end
          when "Bone"
            put_symbol(:l_bracket, X_pos[i], threshold[i] / 10 * 24 + 69, bc_color)
            if scaleout[i]
              put_symbol(:l_scaleout, X_pos[i], threshold[i] / 10 * 24 + 69, bc_color)
            end
          end
        end
      end
    end
   
    if audiodata[:mode] == "Air"  # 気導の場合は周波数間の線を描く
      i = 0
      while i < 6
        if scaleout[i] or (not threshold[i])
          i += 1
          next
        end
#        line_from = [X_pos[i],(threshold[i] / 10 * 24 + 69).prec_i]
        line_from = [X_pos[i],(threshold[i] / 10 * 24 + 69).to_i]
                        # prec_i は float => integer のメソッド, 逆は prec_f #ruby1.9で廃止
        j = i + 1
        while j < 7
          if not threshold[j]
            if j == 6
              i += 1
            end
            j += 1
            next
          end
          if scaleout[j]
            i += 1
            break
          else
#            line_to = [X_pos[j],(threshold[j] / 10 * 24 + 69).prec_i]
            line_to = [X_pos[j],(threshold[j] / 10 * 24 + 69).to_i]
            case audiodata[:side]
            when "Rt"
              line(line_from[0],line_from[1],line_to[0],line_to[1],rt_color,"line")
            when "Lt"
              line(line_from[0],line_from[1]+1,line_to[0],line_to[1]+1,lt_color,"dot")
            end
            i = j
            break
          end
        end
      end
    end
  end

  def draw(filename)
    draw_sub(@air_rt, "latest")
    draw_sub(@air_lt, "latest")
    draw_sub(@bone_rt, "latest")
    draw_sub(@bone_lt, "latest")

    output(filename)
  end

  def predraw(preexams) # preexams は以前のデータの配列，要素はAudiodata
                        # preexams[0]が最も新しいデータ
    revert_exams = Array.new
    predata_n = Overdraw_times - 1
    element_n = (preexams.length < predata_n)? preexams.length: predata_n
               # 要素数か(重ね書き数-1)の小さい方の数を有効要素数とする
    element_n.times do |i|
      revert_exams[i] = preexams[element_n-i-1]
    end        # 古い順に並べ直す

    # 有効な要素の中で古いものから描いていく
    element_n.times do |i|
      exam = revert_exams[i]
      timing = "pre#{i}"
      draw_sub(exam.extract[:ra], timing)
      draw_sub(exam.extract[:la], timing)
      draw_sub(exam.extract[:rb], timing)
      draw_sub(exam.extract[:lb], timing)
    end
  end

end

#----------------------------------------#
if ($0 == __FILE__)
=begin
  datafile = "./Data/data_with_mask.dat"
  #datafile = "./Data/data1.dat"
  #datafile = "./Data/data2.dat"
  buf = String.new
  File.open(datafile,"r") do |f|
    buf = f.read
  end
  d = Audiodata.new("raw", buf)
  a = Audio.new(d)

  p a.mean6
  p a.put_rawdata
  
  puts "pre draw"
  
  a.draw
  
  puts "pre output"
  
  a.output("./test.ppm")    
=end
#----------
  ra = ["0","10","20","30","40","50","60"]
  la = ["1","11","21","31","41","51","61"]
  rm = ["b0","b10","b20","b30","b40","b50","b60"]
  lm = ["w1","w11","w21","w31","w41","w51","w61"]

  dd = Audiodata.new("cooked", ra,la,ra,la,rm,lm,lm,rm)
  aa = Audio.new(dd)

  p aa.reg_mean4
  p aa.put_rawdata

#  aa.draw
#  aa.output("./test.png")
aa.draw("./test2.png")

end
