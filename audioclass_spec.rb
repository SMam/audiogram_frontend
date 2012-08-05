# coding:utf-8
require './audio_class'

rawsample_empty = "7@/          /  080604  //          ,          ,          ,          ,          ,          ,          ,          ,          ,          ,          ,          ,          ,          ,          ,          ,          ,          ,          ,          ,          ,          ,        ,        ,        ,        ,        ,        ,        ,        ,        ,        ,        ,        ,        ,        ,        ,        ,        ,        ,        ,        ,        ,        ,/R"
rawsample_complete = "7@/          /  080604  //   0   30 ,  10   35 ,  20   40 ,          ,  30   45 ,          ,  40   50 ,          ,  50   55 ,          ,  60   60 ,          , -10   55 ,  -5   55 ,          ,   0   55 ,          ,   5   55 ,          ,  10   55 ,          ,  15   55 ,  4>  4<,  4>  4<,  4>  4<,        ,  4>  4<,        ,  4>  4<,        ,  4>  4<,        ,  4>  4<,        ,  4>  4<,  4>  4<,        ,  4>  4<,        ,  4>  4<,        ,  4>  4<,        ,  4>  4<,/P"
#  125 250 500  1k  2k  4k  8k
#R   0  10  20  30  40  50  60
#L  30  35  40  45  50  55  60

rawsample_incomplete = "7@/          /  080604  //          ,          ,          ,          ,  30   45 ,          ,          ,          ,  50   55 ,          ,          ,          , -10   55 ,  -5   55 ,          ,   0   55 ,          ,   5   55 ,          ,  10   55 ,          ,  15   55 ,  4>  4<,  4>  4<,  4>  4<,        ,  4>  4<,        ,  4>  4<,        ,  4>  4<,        ,  4>  4<,        ,  4>  4<,  4>  4<,        ,  4>  4<,        ,  4>  4<,        ,  4>  4<,        ,  4>  4<,/C"
rawsample_broken =""
# raw sample usage
#   d = Audiodata.new("raw", data_string)
#   a = Audio.new(d)

cooked_sample = {:ra => ["0","10","20","30","40","50","60"],\
                 :la => ["1","11","21","31","110","51","61"],\
                 :rm => ["b0","b10","b20","b30","b40","b50","b60"],\
                 :lm => ["w1","w11","w21","w31","w41","w51","w61"]}
cs = cooked_sample # 長いのでエイリアス
# cooked sample usage
#   d = Audiodata.new("cooked", ra,la,ra,la,rm,lm,lm,rm)
#   a = Audio.new(d)

describe Audio do
  before :each do
    @bg_file = "./assets/background.png"
    @output_file = "./output.png"

    File::delete(@output_file) if File::exists?(@output_file)
  end

  context 'background.pngがない場合' do
    it '新しくbackground.pngを作ること' do
      File::delete(@bg_file) if File::exists?(@bg_file)
      a = Audio.new(Audiodata.new("raw", rawsample_complete))
      File::exists?(@bg_file).should be_true
    end
  end

  context '空データで出力した場合' do
    before do
      a = Audio.new(Audiodata.new("raw", rawsample_empty))
      a.draw(@output_file)
    end

    it 'ファイルに出力されること' do
      File::exists?(@output_file).should be_true
    end

    it '出力は background.pngと同じサイズであること' do
      File::stat(@output_file).size.should == File::stat(@bg_file).size
    end
  end

  context 'Audioを正しいraw dataで作成した場合' do
    before do
      @a = Audio.new(Audiodata.new("raw", rawsample_complete))
      @a.draw(@output_file)
    end

    it 'ファイル出力されること' do
      File::exists?(@output_file).should be_true
    end

    it 'mean4の出力が正しいこと' do
      @a.mean4[:rt].should == 30.0
      @a.mean4[:lt].should == 45.0
    end

    it 'reg_mean4(正規化したもの)の出力が正しいこと' do
      @a.reg_mean4[:rt].should == 30.0
      @a.reg_mean4[:lt].should == 45.0
    end

    it 'mean3の出力が正しいこと' do
      @a.mean3[:rt].should == 30.0
      @a.mean3[:lt].should == 45.0
    end

    it 'mean6の出力が正しいこと' do
      @a.mean6[:rt].should == 35.0
      @a.mean6[:lt].should == 47.5
    end

    it 'put_rawdataでもともとのデータ文字列と同じdataが出力されること' do
    # もとのデータ文字列(rawsample_complete)がput_rawdataの出力結果を含むこと
      rawsample_complete.index(@a.put_rawdata).should be_true
    end

    it '出力は background.pngと異なったサイズであること' do
      File::stat(@output_file).size.should_not == File::stat(@bg_file).size
    end
  end

  context 'Audioをデータが足りないraw dataで作成した場合' do
    before do
      @a = Audio.new(Audiodata.new("raw", rawsample_incomplete))
      @a.draw(@output_file)
    end

    it 'ファイル出力されること' do
      File::exists?(@output_file).should be_true
    end

    it 'mean4の出力が-100.0になること' do
      @a.mean4[:rt].should == -100.0
      @a.mean4[:lt].should == -100.0
    end

    it 'mean6の出力が-100.0になること' do
      @a.mean6[:rt].should == -100.0
      @a.mean6[:lt].should == -100.0
    end

    it 'put_rawdataでもともとのデータ文字列と同じdataが出力されること' do
    # もとのデータ文字列(rawsample_complete)がput_rawdataの出力結果を含むこと
      rawsample_incomplete.index(@a.put_rawdata).should be_true
    end
  end

  context 'Audioをcooked dataで作成した場合' do
    before do
      @a = Audio.new(Audiodata.new("cooked", \
                                  cs[:ra],cs[:la],cs[:ra],cs[:la],\
				  cs[:rm],cs[:lm],cs[:lm],cs[:rm]))
      @a.draw(@output_file)
    end

    it 'ファイル出力されること' do
      File::exists?(@output_file).should be_true
    end

    it 'mean4の出力が正しいこと' do
      @a.mean4[:rt].should == 30.0
      @a.mean4[:lt].should == 48.25
    end

    it 'reg_mean4(正規化したもの)の出力が正しいこと' do
      @a.reg_mean4[:rt].should == 30.0
      @a.reg_mean4[:lt].should == 47.0
    end
  end
end

=begin
1) ファイル出力されること

2) データ文字列が壊れていればエラーを出すこと

3) mean4、mean6、mean3、reg_mean4正規化4分法の出力が正しいこと

4) データが足りないときにはmean*はそれぞれ-100.0を出力すること

5) put_rawdataでデータ文字列と同じものが出力されること

6) outputでpngを出力できること

cooked dataでも上の１〜６が可能であること 
=end

=begin
array_spec.rb sample

describe Array, "when empty" do
  before do
    @empty_array = []
  end

  it "should be empty" do
    @empty_array.should be_empty
  end

  it "should size 0" do
    @empty_array.size.should == 0
  end

  after do
    @empty_array = nil
  end
end
=end

=begin
ひとことで言うなら、 describe はテストする対象をあらわし、 context はテストする時の状況をあらわします。

describe Stack do
  before do
    @stack = Stack.new
  end

  describe '#push' do
    context '正常値' do
      it '返り値はpushした値であること' do
        @stack.push('value').should eq 'value'
      end
    end

    context 'nilをpushした場合' do
      it '例外であること' do
        lambda { @stack.push(nil) }.should raise_error(ArgumentError)
      end
    end
  end

  describe '#pop' do
    context 'スタックが空の場合' do
      it '返り値はnilであること' do
        @stack.pop.should be_nil
      end
    end

    context 'スタックに値がある場合' do
      it '最後の値を取得すること' do
        @stack.push 'value1'
        @stack.push 'value2'
        @stack.pop.should eq 'value2'
      end
    end
  end

  describe '#size' do
    it 'スタックのサイズを返すこと' do
      @stack.size.should eq 0

      @stack.push 'value'
      @stack.size.should eq 1
    end
  end
end
												 今回、describe はメソッド単位でわけました。理由としてはテストケースを書くときは何らかのメソッドを対象としていることがほとんどのため、このようにわけた方がテストが書き易いことが多いためです。またメソッド単位でわけることでドキュメントとしても読み易くなります。
=end
