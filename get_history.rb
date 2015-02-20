#!/usr/bin/ruby
require 'curb' 
require 'JSON'
require 'Base64'
require 'cgi'
require 'hmac-sha1'
require 'URI'
require 'time'
require 'openssl'
require 'digest/md5'
require 'mongo'


#Первый запрос  - авторизация. простой post
#Не забудьте поменять параметры
http = Curl.post("http://api.onlinepbx.ru/vash_sip_domain.onpbx.ru/auth.json", {
  :auth_key => "vash_api_key_iz_paneli_upravleniya",
  #Всегда true
  :new      => "true"
})
#Преобразовать в Json
res = JSON.parse http.body_str
#Если авторизация не удалась - убить скрипт
exit 'Авторизация не удалась' if res['status'] != 1


#Формируем хэш с запросом для OnlinePBX
query_param = 
  {
                #Тут конечно выборка на ваш вкус и цвет
  :date_from => (Time.now.utc-(60*60*24)*10).rfc2822

  }


#Спец заголовок
content_type = "application/x-www-form-urlencoded"
#Адрес из API для запроса
url = 'api.onlinepbx.ru/onlinepbx.ru/history/search.json'

#Разбор ключей полученых после авторизации
key_id = res['data']['key_id']
secret_key = res['data']['key']

#Формирование даты... 
date = Time.now.utc
date = (date.rfc2822).gsub!("-0000", "+0000")

#Перегоняем в uri-encode и затем загоняем в md5
post_data = URI.encode_www_form query_param
md5_post_data = Digest::MD5.hexdigest post_data

#Просто POST
method = 'POST'

#Собираем солянку для запроса
for_hash_hmac = method+"\n"+md5_post_data+"\n"+content_type+"\n"+date+"\n"+url+"\n"

#Шифруем солянку secret_key'ем
hmac = HMAC::SHA1.new(for_hash_hmac)
hmac.update(secret_key)
hash_hmac = Base64.encode64(Digest::HMAC.hexdigest(for_hash_hmac, secret_key, Digest::SHA1)).chomp
signature = hash_hmac



#Солянка соединяется с id ключа и передается в качестве хидера
xpbx = "#{key_id}:#{signature}"


#Собираем хидеры
headers = {
  :Date=> date,
  :Accept => 'Application/json',
  'Content-Type'=> 'application/x-www-form-urlencoded',
  'x-pbx-authentication'=> xpbx,
  'Content-MD5'=> md5_post_data
}
p signature
p '-------'

#Последний запрос, указываем хидеры и параметры для POST
http_new = Curl.post('http://'+url, query_param) do |http|
  http.headers = headers
end

#Наслаждаемся результатом
JSON.parse(http_new.body_str)['data'].each do |call|
     p call
end

