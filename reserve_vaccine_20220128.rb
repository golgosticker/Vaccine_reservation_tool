#!/usr/bin/env ruby

require 'date'
require 'selenium-webdriver'

#
# return current time
#
def time_now
    return(Time.now.strftime("%Y-%m-%d %H:%M:%S.%L"))
end

#
# return elements of maru/sankaku from calendar
#
def find_maru_sankaku(driver)
    maru_sankaku_days = []
    ["▲", "●"].each { |maru_sankaku|
        begin
            maru_sankaku_days += driver.find_elements(:partial_link_text, maru_sankaku)
        rescue
            printf("Error: find_maru_sankaku() %s\n", $!)
            next
        end
    }

    return(maru_sankaku_days)
end

#
# check args
#
(shikuchoson_code, sesshuken_bango, seinengappi) = ARGV
if (shikuchoson_code !~ /^\d{6}$/) \
|| (sesshuken_bango  !~ /^\d{10}$/) \
|| (seinengappi      !~ /^\d{8}$/)
    printf("Usage: %s 市区町村コード(6桁) 接種券番号(10桁) 生年月日(8桁)\n", File.basename($0))
    printf("Example: %s 012345 0123456789 20010203\n", File.basename($0))
    exit(-1)
end
(seinengappi_year, seinengappi_month, seinengappi_day) = seinengappi.scan(/^(.{4})(.{2})(.{2})$/)[0]

#
# init browser
#
options = Selenium::WebDriver::Chrome::Options.new(detach: true)
driver  = Selenium::WebDriver.for(:chrome, capabilities: options)
#driver.manage.timeouts.implicit_wait = 0.25

#
# login auth
#
printf("%s login auth\n", time_now())
driver.get("https://www.vaccine.mrso.jp/sdftokyo/VisitNumbers/visitnoAuth/")

name = driver.find_element(:xpath, "//input[@name='data[VisitnoAuth][name]']")
name.send_keys(shikuchoson_code)
printf("%s login auth shikuchoson_code entered\n", time_now())

visitno = driver.find_element(:xpath, "//input[@name='data[VisitnoAuth][visitno]']")
visitno.send_keys(sesshuken_bango)
printf("%s login auth sesshuken_bango entered\n", time_now())

year = driver.find_element(:xpath, format("//select[@name='data[VisitnoAuth][year]']/option[@value=%s]", seinengappi_year))
year.click()
printf("%s login auth seinengappi_year entered\n", time_now())

month = driver.find_element(:xpath, format("//select[@name='data[VisitnoAuth][month]']/option[text()='%s']", seinengappi_month))
month.click()
printf("%s login auth seinengappi_month entered\n", time_now())

day = driver.find_element(:xpath, format("//select[@name='data[VisitnoAuth][day]']/option[text()='%s']", seinengappi_day))
day.click()
printf("%s login auth seinengappi_day entered\n", time_now())

submit = driver.find_element(:xpath, '//button[@type="submit"]')
submit.click()

#
# sesshusha joho kakunin
#
printf("%s sesshusha joho kakunin\n", time_now())
submit = driver.find_element(:xpath, '//*[@id="firstConfirmForm"]/div[2]/div/div')
submit.click()

#
# calendar
#
printf("%s calendar\n", time_now())
date = Date.today
year      = date.year
next_year = date.next_year.year
month      = date.month
next_month = date.next_month.month
day           = date.day
month_end_day = Date.new(year, month, -1).day
printf("year=%d month=%d day=%d month_end_day=%d next_year=%d next_month=%d\n", year, month, day, month_end_day, next_year, next_month)

i = 0
url1 = format("https://www.vaccine.mrso.jp/sdftokyo/CustomPlans/detail/44651/%04d-%02d/#calendar", year, month)
url2 = format("https://www.vaccine.mrso.jp/sdftokyo/CustomPlans/detail/44651/%04d-%02d/#calendar", ((month < next_month) ? year : next_year), next_month)
while true
    sleep(0.5)

    #
    # open calendar page
    #
    if (14 <= (month_end_day - day))
        # check this month
        driver.get(url1)
    else
        # check this month and next month alternately
        if ((i % 2) == 0)
            # this month
            driver.get(url1)
            i += 1
        else
            # next month
            driver.get(url2)
            i = 0
        end
    end

    #
    # find maru/sankaku days from calendar
    #
    maru_sankaku_days = find_maru_sankaku(driver)
    unless maru_sankaku_days.empty?
        printf("\n%s maru_sankaku_days=%d", time_now(), maru_sankaku_days.size)
        begin
            maru_sankaku_days[0].click()
        rescue
            printf("Error: maru_sankaku_days %s\n", $!)
            next
        end
    else
        print(".")
        next
    end

    #
    # select time nokori waku from jikan sentaku
    #
    begin
        nokori_waku_times = driver.find_elements(:partial_link_text, "(残り")
        #printf("%s nokori_waku_times=%d\n", time_now(), nokori_waku_times.size)
        printf(" nokori_waku_times=%d\n", nokori_waku_times.size)
        next if nokori_waku_times.empty?
        nokori_waku_times[0].click()
    rescue
        printf("Error: nokori_waku_times %s\n", $!)
        next
    end

    #
    # situmon kakunin
    #
    printf("%s situmon kakunin\n", time_now())
    begin
        kakunin1_checkbox = driver.find_element(:xpath, '//*[@id="extra_check00"]')
        kakunin1          = driver.find_element(:xpath, '//*[@id="inputForm"]/section/div/div/div[3]/label')
        unless kakunin1_checkbox.selected?
            printf("%s situmon kakunin1 checked\n", time_now())
            kakunin1.click()
        end
        kakunin2_checkbox = driver.find_element(:xpath, '//*[@id="extra_check10"]')
        kakunin2          = driver.find_element(:xpath, '//*[@id="inputForm"]/section/div/div/div[4]/label')
        unless kakunin2_checkbox.selected?
            printf("%s situmon kakunin2 checked\n", time_now())
            kakunin2.click()
        end
        submit = driver.find_element(:xpath, '//*[@id="inputForm"]/section/div/div/div[5]/button')
        submit.click()
    rescue
        printf("Error: situmon kakunin %s\n", $!)
        next
    end

    #
    # yoyaku naiyo kakunin
    #
    printf("%s yoyaku naiyo kakunin\n", time_now())
    begin
        submit = driver.find_element(:xpath, '//*[@id="reserveConfirmForm"]/div/div/div[4]/button')
        submit.click()
    rescue
        printf("Error: yoyaku naiyo kakunin %s\n", $!)
        next
    end

    #
    # reservation succeeded/failed
    #
    page_source = driver.page_source
    if (page_source =~ /接種予約が下記で確定しました/)
        printf("%s reservation succeeded\n", time_now())
        begin
            driver.execute_script("document.getElementsByTagName('html')[0].style['zoom'] = 0.67")
            sleep(1)
            filename = format("reserve_vaccine_%s.png", time_now.gsub(/-|:| /, ''))
            driver.save_screenshot(filename)
            driver.execute_script("document.getElementsByTagName('html')[0].style['zoom'] = 1")
            printf("%s saved screenshot, %s\n", time_now(), filename)
        rescue
            printf("Error: save_screenshot %s\n", $!)
        end
        #driver.get("https://www.vaccine.mrso.jp/sdftokyo/Reserves/")
        exit(0)
    end
    if (page_source =~ /予約枠が無くなりました/)
        printf("%s reservation failed\n", time_now())
        next
    end

    printf("%s reservation failed, you may have already reserved\n", time_now())
    exit(-1)
end

#driver.close()
