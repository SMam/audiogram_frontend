require 'timeout'
require 'rubygems'
require 'serialport'

def get_data_from_audiometer
  port = "/dev/cuaU0"
  baud_rate = 9600
  data_bits = 7
  stop_bits = 1
  parity = SerialPort::EVEN
  timelimit = 1200   # i.e. 1200 seconds = 20 mins

  sp = SerialPort.new(port, baud_rate, data_bits, stop_bits, parity)
  stream = String.new

  begin
    status = timeout(timelimit) do   # timeout処理
      while ( c = sp.read(1) ) do    # RS-232C in
        stream << c
        return stream if c[0] == 0x3 # "R"[0] #=> 82 と文字コードがとれる
      end
    end
  rescue Timeout::Error
    return "Timeout" # 時間切れなら"Timeout"を返す
  end

end

if ($0 == __FILE__)
  d = get_data_from_audiometer
  puts d
  File.open("./data.dat","w") do |f|
    f.puts(d)
  end
end

