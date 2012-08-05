#!/usr/local/bin/ruby
#  Class Audiodata: 聴検"生データ"取扱い用クラス
#  Copyright 2007-2009 S Mamiya <MamiyaShn@gmail.com>
#  0.20091210 : maskの内容がnilだった時にmake_condition_string_for_each_freqでエラーが出るのを修正
#  0.20120516 : Ruby1.9に対応。文字コードを得る方法が str[0] から str.getbyte(0) に変更になっている

class Audiodata
  def initialize(mode, *data) # ここに入るのはRS-232Cから得た生データ、あるいは処理されたデータ列
                              # *args で不定長の引数を受けられる
    if mode == "raw"
      @made_from_rawdata = true
      if data[0][0..2] ==  "7@"
        expand_rawdata("raw", data[0]) # 生データから左右各周波数データに展開
      else
        raise "format error"
      end
    elsif mode == "chop"
      expand_rawdata("chop", data[0]) # 生データから左右各周波数データに展開
    else # 処理済データの場合: dataは [0]=ra_data, [1]=la_data, [2]=rb_data, [3]=lb_data,
         # [4]=ra_mask, [5]=la_mask, [6]=rb_mask, [7]=lb_mask で内容はarray
      #@made_from_rawdata = false
      @ra = {:side => 'Rt', :mode => 'Air', :data => data[0], :scaleout => [], :mask => []}
      @la = {:side => 'Lt', :mode => 'Air', :data => data[1], :scaleout => [], :mask => []}
      @rb = {:side => 'Rt', :mode => 'Bone', :data => data[2], :scaleout => [], :mask => []} if data[2]
      @lb = {:side => 'Lt', :mode => 'Bone', :data => data[3], :scaleout => [], :mask => []} if data[3]
      for d in [@ra, @la, @rb, @lb]
        for i in 0..6
          case d[:data][i].class.to_s
          when "Hash"                        # Hash なら {:data, :scaleout} のデータ形式
            if d[:data][i][:data].class.to_s == "Fixnum"
              d[:data][i][:data] = d[:data][i][:data].prec_f
            end
            if d[:data][i][:data].class.to_s == "Float"
              if d[:data][i][:scaleout] == nil or d[:data][i][:scaleout] == false
                d[:scaleout][i] = d[:data][i][:scaleout]
              else
                d[:scaleout][i] = true
              end
              d[:data][i] = d[:data][i][:data] + 0.0
            else
              d[:data][i] = d[:scaleout][i] = nil              # データは無効
            end
          when "Float"
            d[:scaleout][i] = false
          when "Fixnum"
            d[:data][i] = d[:data][i] + 0.0  # 数字の時はfloatにする
            d[:scaleout][i] = false
          when "String"
            if /((?:-|)\d+)_/ =~ d[:data][i] # データ形式が文字列で、数字の次に "_" が来たら
              d[:data][i] = $1.to_i + 0.0    # 数字を取り出してfloatで格納し
              d[:scaleout][i] = true         # scaleout を true にする
            elsif /((?:-|)\d+)/ =~ d[:data][i] # データ形式が文字列で、数字なら
              d[:data][i] = $1.to_i + 0.0    # 数字を取り出してfloatで格納
            else
              d[:data][i] = d[:scaleout][i] = nil              # さもなくばデータは無効
            end
          else
            d[:data][i] = d[:scaleout][i] = nil                # データは無効
          end
        end
      end
      @ra[:mask] = make_maskdata(data[4]) if data[4]
      @la[:mask] = make_maskdata(data[5]) if data[5]
      @rb[:mask] = make_maskdata(data[6]) if data[6]
      @lb[:mask] = make_maskdata(data[7]) if data[7]
      @rawdata = set_rawdata
    end
  end

  def set_rawdata
    data_string = ""

    [[@ra, @la], [@rb, @lb]].each do |conductions|
      for i in 0..2          # for 125, 250, 500Hz
        data_string << make_data_string_for_each_freq(conductions, i)
      end
      
      for i in 3..6          # for 1k, 2k, 4k, 8kHz
        data_string << (" " * 10 + ",")      # for 800, 1.5k, 3k, 6kHz (void)
        data_string << make_data_string_for_each_freq(conductions, i)
      end
    end

    [[@ra, @la], [@rb, @lb]].each do |conductions|
      for i in 0..2          # for 125, 250, 500Hz
        data_string << make_condition_string_for_each_freq(conductions, i)
      end
      
      for i in 3..6          # for 1k, 2k, 4k, 8kHz
        data_string << (" " * 8 + ",")      # for 800, 1.5k, 3k, 6kHz (void)
        data_string << make_condition_string_for_each_freq(conductions, i)
      end
    end
    return data_string
  end

  def make_data_string_for_each_freq(conductions, i)
    result = ""
    conductions.each do |eachside_data|
      d = eachside_data[:data][i].to_i
      if d
        #d = d.to_i
        if eachside_data[:scaleout][i]
          added_str = "(" + " " * (3 - d.to_s.length) + d.to_s + ")"
        else
          added_str = " " + " " * (3 - d.to_s.length) + d.to_s + " "
        end
      else
        added_str = " " * 5
      end
      result << added_str
    end
    result << ","
    return result
  end

  def make_condition_string_for_each_freq(conductions, i)
    result = ""
    conductions.each do |eachside_data|
      if eachside_data[:mask][i] and eachside_data[:mask][i][1]
                            #  maskingの数字が入力されている場合
        case eachside_data[:mask][i][0]
        when "b", "B"
          masknoise = 2     # band noise
        when "w", "W"
          masknoise = 1     # white noise
        else
          masknoise = 0     # no noise
        end
        
        masknoise_rank = eachside_data[:mask][i][1] > 59? 1: 0
        cond_code1 = "%c" % (0x30 + masknoise * 2 + masknoise_rank)
        masknoise_level = masknoise_rank == 0? (eachside_data[:mask][i][1]+20)/5: \
                                               (eachside_data[:mask][i][1]-60)/5
        cond_code2 = "%c" % (0x30 + masknoise_level)
        condition_string = "  " + cond_code1 + cond_code2
      else
        condition_string = " " * 4
      end
      result << condition_string
    end
    result << ","
    return result
  end

  def expand_rawdata(mode, raw)
    if mode == "raw"
      @rawdata = clip_data(raw)
    else
      @rawdata = raw
    end
    if /error\Z/ =~ @rawdata
      puts "error" # <======================= for debug
    end
 
    each_data, each_scaleout = extract_data(@rawdata, 0)
    @ra = {:side => 'Rt', :mode => 'Air', :data => each_data, :scaleout => each_scaleout, :mask => []}
    each_data, each_scaleout = extract_data(@rawdata, 5)
    @la = {:side => 'Lt', :mode => 'Air', :data => each_data, :scaleout => each_scaleout, :mask => []}
    each_data, each_scaleout = extract_data(@rawdata, 121)
    @rb = {:side => 'Rt', :mode => 'Bone', :data => each_data, :scaleout => each_scaleout, :mask => []}
    each_data, each_scaleout = extract_data(@rawdata, 126)
    @lb = {:side => 'Lt', :mode => 'Bone', :data => each_data, :scaleout => each_scaleout, :mask => []}

    if @rawdata.length > 243
      @ra[:mask] = decode_mask( extract_maskdata(@rawdata, 242))
      @la[:mask] = decode_mask( extract_maskdata(@rawdata, 246))
      @rb[:mask] = decode_mask( extract_maskdata(@rawdata, 341))
      @lb[:mask] = decode_mask( extract_maskdata(@rawdata, 345))
    end
  end

  def clip_data(data)
    i = 0
    bcc = 0
    separator_count = 0
    while data.getbyte(i) != 2     # <stx>までスキップする ruby1.9
      i += 1
    end
    i += 1
    return "machine_error" if data.getbyte(i) != 0x37 # 検査機器コードの確認 ruby1.9
    bcc ^= data.getbyte(i)         # ruby1.9
    i += 1

    return "exam_error" if data.getbyte(i) != 0x40 # 検査項目コードの確認 ruby1.9
    bcc ^= data.getbyte(i)         # ruby1.9
    i += 1

    while c = data.getbyte(i)      #ruby1.9
      if c == 0x2f then     # 区切り文字があれば数をかぞえて
        separator_count += 1
        case separator_count
        when 4              # 4つめの次と
          data_begin = i + 1
        when 5              # 5つめの前をマーク
          data_end = i - 1
        end
      end
      bcc ^= c              # 傍らでひたすらXORを取り続ける
      i += 1
      break if separator_count == 5     # 5つめの区切り文字がでたら終了
    end
    if bcc != data.getbyte(i) then              # <bcc>とその手前までのデータのXORを比較 ruby1.9

puts "BCC error"

      return "communication_error"      # 異なれば通信エラー
    else
      return data[data_begin..data_end] # 等しければ検査データのみを返す
    end
  end

  def extract_data(exam_data, offset)   # rawdataから125,250,500,1k,2k,4k,8kHzの
                                        # データを取り出す. offsetは該当データ開始部位
    results = Array.new
    scaleouts = Array.new
    for i in 0..2
      data = exam_data[offset+i*11..offset+4+i*11]
      if /\(\s*((?:-|)\d+)\s*\)/ =~ data # カッコを伴う数字(負数も可)であれば
        results << ($1.to_i + 0.0)
        scaleouts << true
      elsif /((?:-|)\d+)/ =~ data # 数字(負数も可)だけであれば
        results << ($1.to_i + 0.0)
        scaleouts << false
      else    # 有効なデータがない場合     
        results << nil
        scaleouts << nil
      end
    end
    for i in 0..3
      data = exam_data[offset+44+i*22..offset+48+i*22]
      if /\(\s*((?:-|)\d+)\s*\)/ =~ data # カッコを伴う数字(負数も可)であれば
        results << ($1.to_i + 0.0)
        scaleouts << true
      elsif /((?:-|)\d+)/ =~ data # 数字(負数も可)だけであれば
        results << ($1.to_i + 0.0)
        scaleouts << false
      else    # 有効なデータがない場合
        results << nil
        scaleouts << nil
      end
    end
    return results, scaleouts
  end

  def extract_maskdata(exam_data, offset)     # rawdataから 125,250,500,1k,2k,4k,8kHzの
                                             # マスキングデータ文字列(配列)を取り出す.
    result = Array.new # offsetは該当データ位置
    for i in 0..2
      result << exam_data[offset+i*9..offset+3+i*9]
    end
    for i in 0..3
      result << exam_data[offset+36+i*18..offset+39+i*18]
    end
    return result
  end

  def decode_mask(mask)     # 条件コード(mask: 配列)からマスキング条件を読み取る
    result = Array.new
    for i in 0..6
      condition_code1 = mask[i][2,1].getbyte(0)
      condition_code2 = mask[i][3,1].getbyte(0)
                # str[i,n] で文字列左から i+1番めからn文字を抜き出す
                # str[0] で文字列の先頭文字のASCII コードが得られる
                # ruby1.9
      case (condition_code1 & 1)
      when 1    # masking noise level >= 60
        mask_level = 60 + (condition_code2 & 15) * 5 
      when 0    # masking noise level <= 55
        mask_level = -20 + (condition_code2 & 15) * 5
      end
      case condition_code1 & 6 
      when 2
        mask_type = 'w' # white noise
      when 4
        mask_type = 'b' # band noise
      else # when 6 and nil
        mask_type = 'n'
        mask_level = 0 # no masking noise
      end
      result << [mask_type, mask_level]
    end
    return result
  end

  def make_maskdata(mask_array) # "b50" という表現から mask_type: "b", mask_level: 50 とする
                                # 或いは Hash なら {:type, :level} の組み合わせ
    result = Array.new
    for i in 0..6
      item = mask_array[i]
      case item.class.to_s
      when "String "
        if item
          if /^([A-Z]+|[a-z]+)(\d+)/ =~ item
            result << [$1, $2.to_i] # [mask_type, mask_level]
          else
            result << nil
          end
        else
          result << item.to_i
        end
      when "Hash"
        item_level = item[:level].to_i if item[:level]
        result << [item[:type], item[:level]]
      end
    end
    return result
  end

  def extract # hashで各データを返す
    result = {:ra => @ra, :la => @la, :rb => @rb, :lb => @lb}
    return result
  end

  def put_rawdata
    return @rawdata
  end
end

#-----
if ($0 == __FILE__)
  #datafile = "./Data/data1.dat"
  datafile = "./Data/data_with_mask.dat"
  buf = String.new
  File.open(datafile,"r") do |f|
    buf = f.read
  end
  d = Audiodata.new("raw", buf)
 
  d2 = d.extract
  p d2[:ra]
  p d2[:la]
  p d2[:rb]
  p d2[:lb]

  p d.put_rawdata

  puts "-----\n"

  ra = ["110_", 10, "120_", 30, 40, 50, 60]
  la = [1, 11, 21, 31, 41, 51, 61]
  rm = ["b0","b10","b20","b30","b40","b50","b60"]
  lm = ["w1","w11","w21","w31","w41","w51","w61"]

  dd = Audiodata.new("cooked", ra,la,ra,la,rm,lm,lm,rm)
  dd2 = dd.extract
  p dd2[:ra]
  p dd2[:la]
  p dd2[:rb]
  p dd2[:lb]

  p "---"
  p dd.put_rawdata

end
