require 'rubygems'
require 'open-uri'
require 'nokogiri'
require 'kconv'

def getHTML(url)
    html = open(url, "r:binary").read
    return Nokogiri::HTML(html.toutf8, nil, 'utf-8')
end

def _guessFromList(str, list)
    list.each{|item|
        if str.include?(item)
            return item
        end
    }
    return "他"
end

def extractSurface(str)
    surface = ["芝右","ダ右","障芝","芝右 外","障芝 ダート","ダ左","芝左","障芝 外","芝左 外","芝直線","障芝 外-内","障芝 内-外","芝右 内2周"]
    _guessFromList(str, surface)
end

def extraceSurfaceCategory(str)
    sc = ["障","芝","ダ"]
    _guessFromList(str, sc)
end

def extraceDirection(str)
    dir = ["直線","右","左"]
    _guessFromList(str, dir)
end

def extractWeather(str)
    weather = ["晴","曇","小雨","雨","雪"]
    _guessFromList(str, weather)
end

def extractCourseState(str)
    state = ["稍重","重","不良","良"]
    _guessFromList(str, state)
end

def extractGrade(str)
    grade = ["オープン","1600万下","3勝クラス","1000万下","2勝クラス","500万下","1勝クラス","未勝利","新馬"]
    _guessFromList(str, grade)
    .gsub(/1600万下/,"3勝クラス")
    .gsub(/1000万下/,"2勝クラス")
    .gsub(/500万下/,"1勝クラス")
end

def extractRaceDate(str)
    dd = str.match(/^(\d+)年(\d+)月(\d+)日$/)
    Date.new(dd[1].to_i, dd[2].to_i , dd[3].to_i)
end

def td(row, index)
    row.xpath("td[#{index}]").text.strip
end

def tdd(row, index)
    row.xpath("diary_snap_cut/td[#{index}]").text.strip
end

def td_a_href(row, index)
    row.xpath("td[#{index}]/a").attribute('href').text.strip
end

def extractSex(str)
    sex = ["牡","牝","セ"]
    _guessFromList(str, sex)
end

def racetimeToSec(str)
    if  m = str.match(/(\d{1}):(\d{2}).(\d{1})/)
        return "#{m[1].to_i*60+m[2].to_i}.#{m[3].to_i}".to_f
    else
        return str
    end
end

def extractRaceResult(id, row)
    place = td(row,1)
    bracket = td(row,2)
    gate = td(row,3)
    horse_id = td_a_href(row,4).match(/\d{10}/)[0]
    name = td(row,4)
    sex_age = td(row,5)
    sex = extractSex(sex_age)
    age = sex_age.match(/(\d+)/)[0].to_i
    lweight = td(row,6)
    jocky_id = td_a_href(row,7).match(/\d{5}/)[0]
    jocky_name = td(row,7)
    race_time = racetimeToSec(td(row,8))
    diff = td(row,9)
    time_index = row.xpath("diary_snap_cut[1]/td")[0].text.strip
    last3f = row.xpath("diary_snap_cut/td")[2].text.strip
    odds = td(row,10)
    popularity = td(row,11)
    weight = td(row,12).match(/(\d{3})/) ? td(row,12).match(/(\d{3})/)[0] : 0
    weightdiff = td(row,12).match(/\d{3}\(([+|-]*\d+)\)/) ? td(row,12).match(/\d{3}\(([+|-]*\d+)\)/)[1] : 0
    trainer = td(row,13).split("\n")[1]
    trainer_id = td_a_href(row,13).match(/\d{5}/)[0]
    owner = row.xpath("diary_snap_cut[3]/td[1]").text.strip
    owner_id = row.xpath("diary_snap_cut[3]/td[1]/a").attribute('href').text.strip.match(/(\d{6}|a\d{5})/)[0]
    prize = row.xpath("diary_snap_cut[3]/td[2]").text.strip

     return "#{id}\t#{place}\t#{bracket}\t#{gate}\t#{horse_id}\t#{name}\t#{sex}\t#{age}\t#{lweight}\t#{jocky_id}\t#{jocky_name}\t#{race_time}\t#{diff}\t#{last3f}\t#{odds}\t#{popularity}\t#{weight}\t#{weightdiff}\t#{trainer_id}\t#{trainer}\t#{owner_id}\t#{owner}\t#{prize}"
end

def extractPayData(tr, category)
    tr.each{|t|
        pay = []
        if t.children[1].text == category
            t.children[5].inner_html.split("<br>").each{|p|
                pay.push p.gsub(/,/,"").to_i
            }
            return pay.join("_")
        end
    }
    return ''
end

def ScrapeRace(id)
    url = "https://db.netkeiba.com/race/#{id}/"

    doc = getHTML(url)
    
    # レース情報
    place = doc.xpath("//ul[@class='race_place fc']//a[@class='active']").inner_text
    race_num = doc.xpath("//ul[@class='fc']//a[@class='active']").inner_text.match(/\d*/).to_s
    name = doc.xpath("//h1").inner_text.strip
    condition = doc.xpath("//diary_snap_cut/span").inner_text.strip

    surface = extractSurface(condition)
    surfaceCategory = extraceSurfaceCategory(surface)
    direction = extraceDirection(surface)
    distance = condition.match(/(\d+)m/)[1]
    weather = extractWeather(condition)
    course_state = extractCourseState(condition)

    description = doc.xpath("//p[@class='smalltxt']").inner_text.split(" ")
    race_date = extractRaceDate(description[0])
    grade = extractGrade(description[2])
    

    # レース結果
    race_results = []
    doc.xpath("//table[@class='race_table_01 nk_tb_common']/tr[position()>1]").each{|row|
        race_results.append(extractRaceResult(id, row))
    }
    
    pay_data = doc.xpath("//table[@class='pay_table_01']/tr")
    p pay_data

    pay_win        = extractPayData(pay_data, '単勝')
    pay_place      = extractPayData(pay_data, '複勝')
    pay_b_quinella = extractPayData(pay_data, '枠連')
    pay_quinella   = extractPayData(pay_data, '馬連')
    pay_q_place    = extractPayData(pay_data, 'ワイド')
    pay_exacta     = extractPayData(pay_data, '馬単')
    pay_trio       = extractPayData(pay_data, '三連複')
    pay_trifecta   = extractPayData(pay_data, '三連単')

    race_info = "#{id}\t#{race_date.strftime("%Y/%m/%d")}\t#{place}\t#{race_num}\t#{name}\t#{surfaceCategory}\t#{direction}\t#{distance}\t#{grade}\t#{weather}\t#{course_state}\t#{pay_win}\t#{pay_place}\t#{pay_b_quinella}\t#{pay_quinella}\t#{pay_q_place}\t#{pay_exacta}\t#{pay_trio}\t#{pay_trifecta}"

    return race_info, race_results
end

race_info, race_results = ScrapeRace(202002020301)
puts race_info, race_results