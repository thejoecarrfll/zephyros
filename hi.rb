require 'socket'
require 'json'
require 'thread'

class Object
  def converted
    if is_a?(Array)
      map(&:converted)
    elsif is_a?(Hash) && has_key?('_type')
      klass = Kernel.const_get(self['_type'])
      klass.new(self['_id'])
    else
      self
    end
  end
end

class Zeph

  def initialize
    @sock = TCPSocket.new 'localhost', 1235
    @id = 0
    @queues = {}

    thread = listen_forever
    at_exit { thread.join }
  end

  def request(data)
    id = send_raw data

    val = @queues[id].pop
    @queues.delete id
    return val[1].converted
  end

  def register(data, blk)
    id = send_raw data

    Thread.new do
      loop do
        event = @queues[id].pop
        blk.call event[1].converted
      end
    end
  end

  private

  def send_raw(data)
    id = @id += 1
    @queues[id] = Queue.new
    json = [id].concat(data).to_json
    @sock.write "#{json.size}\n#{json}"
    return id
  end

  def listen_forever
    Thread.new do
      loop do
        size = @sock.gets
        msg = @sock.read(size.to_i)
        val = JSON.load(msg)
        id = val[0]
        @queues[id] << val
      end
    end
  end

end

$zeph = Zeph.new


module ZephProxy

  def forward_methods(methods)
    methods.each do |method_name|
      define_method(method_name) do |*args, &blk|
        $zeph.request [id, method_name, *args], &blk
      end
    end
  end

end


module API

  class << self

    extend ZephProxy
    define_method(:id) { 0 }
    forward_methods [:choose_from,
                     :alert,
                     :log,

                     :bind,
                     :listen,

                     :focused_window,
                     :visible_windows,
                     :all_windows,

                     :main_screen,
                     :all_screens,

                     :running_apps]

  end

end

class Point < Struct.new(:x, :y)

  def self.from_hash(d)
    r = new
    r.x = d['x']
    r.y = d['y']
    r
  end

  def to_hash
    {
      'x' => x,
      'y' => y,
    }
  end

  def initialize
    self.x = 0
    self.y = 0
  end

end

class Size < Struct.new(:w, :h)

  def self.from_hash(d)
    r = new
    r.w = d['w']
    r.h = d['h']
    r
  end

  def to_hash
    {
      'w' => w,
      'h' => h,
    }
  end

  def initialize
    self.w = 0
    self.h = 0
  end

end

class Rect < Struct.new(:x, :y, :w, :h)

  def self.from_hash(d)
    r = new
    r.x = d['x']
    r.y = d['y']
    r.w = d['w']
    r.h = d['h']
    r
  end

  def to_hash
    {
      'x' => x,
      'y' => y,
      'w' => w,
      'h' => h,
    }
  end

  def initialize
    self.x = 0
    self.y = 0
    self.w = 0
    self.h = 0
  end

  def self.make(x, y, w, h)
    r = Rect.new
    r.x = x
    r.y = y
    r.w = w
    r.h = h
    r
  end

  def inset!(x, y)
    self.x += x
    self.y += y
    self.w -= (x * 2)
    self.h -= (y * 2)
    self
  end

  def min_x; x; end
  def min_y; y; end
  def max_x; x + w; end
  def max_y; y + h; end

end

$window_grid_width = 3
$window_grid_margin_x = 5
$window_grid_margin_y = 5

class Window < Struct.new(:id)

  extend ZephProxy
  forward_methods [:other_windows_on_same_screen,

                   :frame=,
                   :top_left=,
                   :size=,

                   :maximize,
                   :minimize,
                   :un_minimize,

                   :screen,
                   :app,

                   :focus_window,
                   :focus_window_left,
                   :focus_window_right,
                   :focus_window_up,
                   :focus_window_down,

                   :normal_window?,
                   :minimized?,

                   :title]

  def frame
    Rect.from_hash $zeph.request([id, :frame])
  end

  def top_left
    Point.from_hash $zeph.request([id, :top_left])
  end

  def size
    Size.from_hash $zeph.request([id, :size])
  end

  def frame=(arg)
    $zeph.request([id, :set_frame, arg.to_hash])
  end

  def top_left=(arg)
    $zeph.request([id, :set_top_left, arg.to_hash])
  end

  def size=(arg)
    $zeph.request([id, :set_size, arg.to_hash])
  end

  def get_grid
    win_frame = self.frame
    screen_rect = self.screen.frame_without_dock_or_menu
    third_screen_width = screen_rect.w / $window_grid_width
    half_screen_height = screen_rect.h / 2.0
    Rect.make(((win_frame.x - screen_rect.min_x) / third_screen_width).round,
              ((win_frame.y - screen_rect.min_y) / half_screen_height).round,
              [(win_frame.w.round / third_screen_width).round, 1].max,
              [(win_frame.h.round / half_screen_height).round, 1].max)
  end

  def set_grid(g, screen)
    screen = screen || self.screen
    screen_rect = screen.frame_without_dock_or_menu
    third_screen_width = screen_rect.w / $window_grid_width
    half_screen_height = screen_rect.h / 2.0
    new_frame = Rect.make((g.x * third_screen_width) + screen_rect.min_x,
                          (g.y * half_screen_height) + screen_rect.min_y,
                          g.w * third_screen_width,
                          g.h * half_screen_height)
    new_frame.inset!($window_grid_margin_x, $window_grid_margin_y)
    new_frame.integral!
    self.frame = new_frame
  end

end

class Screen < Struct.new(:id)

  extend ZephProxy
  forward_methods [:next_screen,
                   :previous_screen]

  def frame_including_dock_and_menu
    Rect.from_hash $zeph.request([id, :frame_including_dock_and_menu])
  end

  def frame_without_dock_or_menu
    Rect.from_hash $zeph.request([id, :frame_without_dock_or_menu])
  end

end

class App < Struct.new(:id)

  extend ZephProxy
  forward_methods [:all_windows,
                   :visible_windows,

                   :title,
                   :hidden?,

                   :show,
                   :hide,

                   :kill,
                   :kill9]

end














10.times do |i|

  if i == 5
    API.bind 'd', ['cmd', 'opt'] do |args|
      p args
    end
  end

  p API.all_windows

end

API.alert 'sup', 3


# win = Window.new(3)
# win.frame = Rect.new
