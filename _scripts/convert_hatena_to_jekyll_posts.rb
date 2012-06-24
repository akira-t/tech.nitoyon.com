# はてなダイアリー Jekyll インポート
# ==================================
#
# はてなダイアリーの「はてなの日記データ形式」でエクスポートしたデータを
# はてな記法のまま Jekyll 形式に変換するスクリプト
#
# プラグインとして converter/hatena.rb を指定して、hparser を利用することで、
# はてなダイアリーとほぼ同等の出力になります。
#
# 実行例:
#     ruby convert_hatena_to_jekyll_posts.rb nitoyon export.xml
#     # 出力先: _posts/YYYY-MM-DD-entry-title.htn

require 'liquid'
require 'rexml/document'
require 'yaml'

# コマンドライン引数を読み取り
if ARGV.length < 2
  abort "USAGE: ruby $0 [hatena_id] [XML file]"
end

hatena_id = ARGV[0]
xml_path = ARGV[1]
puts "\nhatena id: #{hatena_id}\nXML path: #{xml_path}\n\n"

def main(hatena_id, xml_path)
  # XML を開く
  file = File.new(xml_path)
  doc = REXML::Document.new file

  # 各日ごとに処理
  # <diary>
  #   <day date="YYYY-MM-DD" title="">
  #     <body>...</body>
  #   </day>
# </diary>
  doc.elements.each("/diary/day") { |e|
    parse_day(e, hatena_id)
  }
end

def parse_day(e, hatena_id)
  date = e.attributes["date"]
  body = e.elements["body"].text
  if date < "2006-01-01" then return end

  # エントリーごとに処理
  # body には複数エントリーが含まれることがある
  # (例)
  #     *p1*エントリー1
  #     あああ
  #     
  #     *p2*エントリー2
  #     あああ
  body.split(/(?=^\*[^\*]+\*)/).each { |entry|
    if entry.strip == "" then
      next
    end

    # 1 行目がタイトル
    title,text = entry.split(/\n/, 2)
    puts "Parsing #{date} '#{title}'..."

    # "*name*[tag1][tag2]name_ja" に分解
    unless m = title.match(/^\*([^*]+)\*(?:\[([^\]]+)\])*(.*)/)
        abort("invalid title: #{title}")
    end
    name = m[1]
    name_ja = m[-1]
    tags = m[2..-2]
    if tags[0].nil? then tags = [] end
    old_url = date.gsub('-', '') + "/" + name
    new_name = name.gsub('_', '-')

    # ファイル出力する
    fn = "_posts/#{date}-#{new_name}.htn"
    File::open(fn, "w") { |f|
      f.write({
        "layout" => "post", 
        "title" => name_ja,
        "tags" => tags.join(","),
        "lang" => "ja",
        "old_url" => "http://d.hatena.ne.jp/#{hatena_id}/#{old_url}",
      }.to_yaml)
      f.write("---\n")
      f.write(convert_text(text, hatena_id))
    }
    puts "Success #{fn}"
  }
end

def convert_text(text, hatena_id)
    # 本文の {% hoge %} や {{ hoge }}が Liquid テンプレートタグとして解釈
    # されないようにしておく
    tokens = text.split(/(#{Liquid::PartialTemplateParser})/)
    tokens.shift if tokens[0] and tokens[0].empty?
    tokens = tokens.map {|t|
      t = "{%raw%}#{t}{%endraw%}" if t.match(Liquid::AnyStartingTag)
      t
    }
    text = tokens.join("")

    # [twitter:123456789:detail] → {% twitter 123456789 %}
    text = text.gsub(/\[twitter:(\d+):detail\]/, '{% twitter \1 %}')

    # [http://d.hatena.ne.jp/#{hatena_id}/YYYYMMDD/name:title]
    # → {% post_link YYYY-MM-DD-name %}
    text = text.gsub(/\[http:\/\/d\.hatena\.ne\.jp\/#{hatena_id}\/(\d{4})(\d{2})(\d{2})\/([^\]]+):title\]/) { |text|
        "{% post_link #{$1}-#{$2}-#{$3}-#{$4.gsub('_', '-')} %}"
    }

    text
end


main(hatena_id, xml_path)
