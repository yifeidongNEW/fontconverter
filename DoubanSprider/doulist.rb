require 'net/http'
require 'nokogiri'
require 'json'

# 获取豆列信息
list_id = ARGV[0]
if list_id == nil then
    p "Can't find target id, please check your input."
    p "-----press any button to exit-----"
    gets
    return
end
# 豆列id

# 等待时间防止被封IP，单位是秒
sleep_time = 1

# 短评论取得条数
short_commet_max = 10
# 长评论取得条数
review_max = 5

# 输出的结果
result_str = ""

# 豆列地址模板
list_api_url = "https://www.douban.com/doulist/#{list_id}/"

# 抓不到api，只能先下载到本地内存里再分析这段html文件结构了，范例：
# list_api_url = "https://movie.douban.com/subject/1292052/comments?status=P"
# list_api_url = "https://movie.douban.com/subject/1292052/reviews"

# 下载豆列页面数据到内存
uri = URI(list_api_url)
response = Net::HTTP.get_response(uri)
doulist_html = Nokogiri::HTML(response.body)   #html格式化

result_str += "豆列地址：#{list_api_url}\n\r\n"

# 获取总页数
page_item = doulist_html.css("div[class='paginator']").css("span")
total_page_num = page_item[1]['data-total-page'].to_i - 1
# 从第1页开始依次遍历
for i in 0..total_page_num
    p "-----------------Page is #{i}/#{total_page_num} -----------------\n\r\n"
    
    # 更新页数
    now_page = i * 25
    uri = URI("https://www.douban.com/doulist/#{list_id}/?start=#{now_page}&sort=seq&playable=0&sub_type=")
    response = Net::HTTP.get_response(uri)
    doulist_html = Nokogiri::HTML(response.body)
    
    # 取每个class="doulist-item"的div，是豆列里的每个元素
    doulist_items = doulist_html.css("div[class='doulist-item']")
    doulist_items.each do | item |
        # 可能需要一点处理，来跳过不是电影的豆列元素
        # 目前采用比较low的方式，判定是否包含“豆瓣电影”字段的div
        source_from = doulist_items.css("div[class='source']")[0].text.strip
        if (source_from.include?"\u6765\u81EA\uFF1A\u8C46\u74E3\u7535\u5F71") == false then
            p "This douitem isn't from douban movie, goto next one."
            break
        end

        # 从豆列逐个获取电影信息
        movie_title = item.css("div[class='title']")[0]
        result_str += "电影《#{movie_title.text.strip}》开始--------------------------------------------------------------------------------\n\r\n"
        result_str += "地址：" + movie_title.css("a")[0]['href'] + "\n\r"                           # 作品连接地址
        result_str += "片名：" + movie_title.text.strip + "\n\r"                                    # 作品名称
        result_str += "评分：" + item.css("div[class='rating']").css("span")[1].text + "\n\r"       # 作品评分
        result_str += "评价数：" + item.css("div[class='rating']").css("span")[2].text + "\n\r"     # 作品评价数量
        
        # 短评论地址
        result_str += "=============短评论开始=============\n\r\n"
        movie_comments_url = movie_title.css("a")[0]['href'] + "comments"
        movie_comments_html = Nokogiri::HTML(Net::HTTP.get_response(URI(movie_comments_url)).body)
        # 遍历短评论中的高赞数的
        now_comment_count = 0
        movie_comments_html.css("div[class='comment-item']").each do | comment |
            # 提取节点内容
            result_str += "短评 #{now_comment_count}/#{short_commet_max}\n\r"
            result_str += "评论时间：" + comment.css("span[class='comment-time ']")[0].text.strip + "\n\r"
            result_str += "短评作者：" + comment.css("span[class='comment-info']").css("a")[0].text.strip + "\n\r"
            result_str += "评论赞数：" + comment.css("span[class='comment-vote']").css("span[class='votes']")[0].text.strip + "\n\r"
            result_str += "短评内容：\n\r" + comment.css("span[class='short']")[0].text.strip + "\n\r\n\r"
            # 计数
            now_comment_count += 1
            if now_comment_count >= short_commet_max then
                break
            end
        end
        result_str += "=============短评论结束=============\n\r\n\r\n"

        # 长评论地址
        result_str += "=============长评论（影评）开始=============\n\r\n"
        movie_reviews_url = movie_title.css("a")[0]['href'] + "reviews"
        movie_reviews_html = Nokogiri::HTML(Net::HTTP.get_response(URI(movie_reviews_url)).body)
        # 遍历长评论中的高赞数的
        now_review_count = 0
        movie_reviews_html.css("div[class='main review-item']").each do | review |
            result_str += "长评 #{now_review_count}/#{review_max}\n\r"
            result_str += "评论时间：" + review.css("header[class='main-hd']").css("span[class='main-meta']")[0].text.strip + "\n\r"
            result_str += "评论作者：" + review.css("header[class='main-hd']").css("a[class='name']")[0].text.strip + "\n\r"
            result_str += "评论标题：" + review.css("div[class='main-bd']").css("h2")[0].text.strip + "\n\r"
            
            # 赞数
            result_str += "赞同数：" + review.css("div[class='main-bd']").css("div[class='action']")[0].css("a")[0].css("span")[0].text.strip+ "\n\r" 
            result_str += "不赞同：" + review.css("div[class='main-bd']").css("div[class='action']")[0].css("a")[1].css("span")[0].text.strip+ "\n\r" 

            # 长评id
            review_short_content = review.css("div[class='main-bd']").css("div[class='short-content']").text.strip
            result_str += "长评预览：\n\r" + review_short_content[0,review_short_content.length-6].strip + "\n\r" 
            result_str += "长评地址：https://movie.douban.com/j/review/" + review['id'] + "/full" + "\n\r\n\r"

            # 计数
            now_review_count += 1
            if now_review_count >= review_max then
                break
            end
        end
        result_str += "=============长评论（影评）结束=============\n\r\n\r\n"

        result_str += "电影《#{movie_title.text.strip}》结束--------------------------------------------------------------------------------\n\r\n\r\n"
        
        
        # 等待，防止访问过快被封ip
        p "----------------#{movie_title.css("a")[0]['href']} finished----------------"
        sleep(sleep_time)
    end

    p "-----------------Page #{i}/#{total_page_num} end-----------------\n\r\n"
end



path = "douban_result"
resultFile = File.new(path + "\\#{list_id}.txt","w+")
resultFile.syswrite(result_str)
resultFile.close()

p "Finished! Your result is '..\\#{path}\\#{list_id}.txt'"
p "-----press any button to exit-----"
gets