require 'net/https'
require 'json'
require 'uri'
require 'zip'
require 'fileutils'

Zip.on_exists_proc = true
Zip.continue_on_exists_proc = true

CDN = URI('https://cdn.discordapp.com/')
@packs = JSON.parse(File.read(File.join(__dir__, 'data.json')))

def get_server_icon_url(id, hash)
  File.join('', 'icons', id, "#{hash}.png?size=4096")
end

def get_emoji_url(id, animated)
  File.join('', 'emojis', "#{id}.#{animated ? 'gif' : 'png'}?size=4096")
end

Net::HTTP.start(CDN.host, CDN.port, use_ssl: CDN.scheme == 'https') do |http|

@packs.each do |pack|
  meta = {id: pack['id'], name: pack['name'], hash: pack['icon']}
  dir = File.join(__dir__, meta[:id])
  FileUtils.mkdir_p(dir)
  Net::HTTP::Get.new(get_server_icon_url(meta[:id], meta[:hash])).tap do |req|
    next if File.exists?(File.join(dir, 'icon.png'))
    res = http.request req
    res.value
    File.binwrite(File.join(dir, 'icon.png'), res.body)
  end
  emotes = []
  edir = File.join(dir, 'emotes')
  FileUtils.mkdir_p(edir)
  pack['content']['emojis']&.each do |emoji|
    next if emoji['name'].downcase.include? 'blob'
    next if emoji['name'].downcase.include? 'google'
    emeta = {id: emoji['id'], name: emoji['name'], animated: emoji['animated']}
    emeta[:ext] = emeta[:animated] ? :gif : :png
    Net::HTTP::Get.new(get_emoji_url(emeta[:id], emeta[:animated])).tap do |req|
      ename = File.join(edir, "#{emeta[:id]}.#{emeta[:ext]}")
      next if File.exists?(ename)
      res = http.request req
      res.value
      File.binwrite(ename, res.body)
    end
    emotes << emeta
  end
  File.write(File.join(dir, 'metadata.json'), JSON.generate(meta))
  File.write(File.join(dir, 'emotes.json'), JSON.generate(emotes))

  Zip::File.open(File.join(dir, 'server.zip'), create: true) do |z|
    %w(icon.png metadata.json emotes.json).each do |fn|
      z.add(fn, File.join(dir, fn))
    end
    emotes.each do |emeta|
      ename = "#{emeta[:id]}.#{emeta[:ext]}"
      next unless File.exists?(File.join(edir, ename))
      z.add(File.join('e', ename), File.join(edir, ename))
    end
  end
end

end