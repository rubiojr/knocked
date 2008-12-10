#!/usr/bin/ruby
begin
  require 'rubygems'
rescue
  puts "Necesitas tener instalado rubygems para poder ejecutar este script."
  exit 1
end

begin
  require 'hpricot'
  require 'mechanize'
  require 'highline/import'
  require 'cmdparse'
  require 'yaml'
rescue
  puts "Necesitas las gemas 'cmdparse', 'hpricot','highline' y 'mechanize' para poder ejecutar el script."
  puts "gem install hpricot mechanize highline"
  exit 1
end

module Knocked 

  VERSION = '0.4'
  class InvalidSettingsException < Exception; end
  class InvalidZoneException < Exception; end
  class TooManyValuesException < Exception; end

  class PtrRecord
    attr_accessor :id, :name, :ip, :aliases

    def to_s
      "#{@id}: #{@ip} #{@name}"
    end

    def =~(r)
      @name =~ r or @ip =~ r
    end
  end

  class ARecord 
    attr_accessor :id, :name, :ip
    def to_s
      "#{@id}: #{@ip} #{@name}"
    end
    
    def =~(r)
      @name =~ r or @ip =~ r
    end
  end

  class  WebApp

    attr_reader :agent
    def self.login
      agent = WWW::Mechanize.new
      w = WebApp.new
      w.instance_eval "@agent = agent"
      page = agent.get(w.settings['app_url'])
      f = page.forms.first
      f.j_username = w.settings['username']
      f.j_password = w.settings['password']
      f.submit
      page = agent.get(w.settings['app_url'])
      if page.title =~ /Valida/
        raise ArgumentError.new("Invalid username/password")
      end
      return w
    end

    def settings
      file = ENV['HOME'] + '/.knockedrc'
      if not File.file?(file)
        raise InvalidSettingsException.new("Invalid settings file in #{file}")
      end
      settings = YAML.load(open(file))
      if not settings.has_key?('app_url')
        raise InvalidSettingsException.new("app_url not specified in settings file: #{file}")
      end
      if not settings.has_key?('username') or not settings.has_key?('password')
        raise InvalidSettingsException.new("username/password not specified in settings file: #{file}")
      end
      return settings
    end

    def mass_add(file, zone, dry_run=true) 
      if not File.file?(file)
        raise ArgumentError("Invalid file #{file}")
      end
      IO.readlines(file).each do |line|
        ip, host = line.chomp.strip.split
        if ip !~ /(\d{1,3}\.){3}\d{1,3}/
          $stderr.puts "Skipping invalid ip: #{line}"
          next
        end
        if host !~ /\.#{zone}$/
          $stderr.puts "Skipping invalid host: #{line}"
          next
        end
        host = host.gsub(".#{zone}", '')
        oct1, oct2, oct3, oct4 = ip.split(".")

        page = agent.get("#{settings['app_url']}/SoaNoIp?id_dnssoa=#{domains[zone]}&tipoAccion=7&dominio=#{zone}")

        form = page.forms.first
        form.o_nombre_a = host
        form.oct1 = oct1
        form.oct2 = oct2
        form.oct3 = oct3
        form.oct4 = oct4
        form.o_ip_a = ip
        form.o_ttl_a = '172800'
        puts "Submitting #{ip} #{host} to zone #{zone}"
        #form.submit if not dry_run
      end
    end

    def available_zones
      return @zones if defined? @zones and not @zones.nil?
      @zones = {}
      p = @agent.get "#{settings['app_url']}/CargaMenuDns"
      (Hpricot(p.root.to_s)/'//option').each do |item|
        zone, id = item['value'].split(',')[0..1]
        @zones[zone] = id
      end
      @zones
    end

    def list_records(zone=nil)
      records = []
      zones = [].concat([zone] || available_zones.keys)
      raise TooManyValuesException.new('Too many zones found. Limit your query.') if zones.size > 10
      zones.each do |z|
        if z =~ /^\d{1,3}[\.0-9]*/
          records.concat list_zone_ptrs(z)
        else
          records.concat list_zone_domains(z)
        end
      end
      return records 
    end

    def find(exp, zone=nil)
      exp = '.*' if exp.nil? or exp.empty?
      findings = []
      zones = [].concat([zone] || available_zones.keys)
      zones.each do |z|
        list_records(z).each do |d|
          findings << d if d =~ /#{Regexp.quote(exp)}/
        end
      end
      return findings
    end

    def barbarize(interval=1)
      records = []
      zones = available_zones.keys
      zones.each do |z|
        yield z if block_given?
        records.concat list_records(z)
        sleep(interval)
      end
      return records
    end

    private
    def list_zone_ptrs(zone)
      if not available_zones.has_key? zone
        raise InvalidZoneException.new("zone mapping not found for #{zone}")
      end
      ptrs = []
      params = {}
      id = available_zones[zone]
      pdata = "pagina=Ptr&iddnssoa=#{id}&dominio=#{zone}&ip=si&tipoAccion=view"
      pdata.split('&').each do |p|
        key, val = p.split('=')
        params[key] = val
      end
      response = @agent.get("#{settings['app_url']}/GestionNavegacionDns", params)
      raise Exception.new('Invalid response from web server.') if response.code != '200'
      doc = Hpricot(response.parser.to_s)
      doc.search("//tr[@class='registros1']").each do |reg|
        fields = (reg/'td')
        ptr = PtrRecord.new
        ptr.id = fields[0].inner_text
        ptr.ip = fields[1].inner_text
        ptr.name = fields[2].inner_text.gsub("?", "")
        # aliases reverse zones?
        # we don't need them right now
        #ptr.aliases = fields[3].to_s.split(/<br\s?\/>/).collect do |i|
        #  val = i.gsub(/<br\s?\/?>|&nbsp;|<\/?td>/, '').strip
        #  val = nil if val.empty?
        #  val
        #end
        ptrs << ptr
      end
      return ptrs
    end

    def list_zone_domains(zone)
      if not available_zones.has_key? zone
        raise InvalidZoneException.new("zone mapping not found for #{zone}")
      end
      domains = []
      params = {}
      id = available_zones[zone]
      pdata = "pagina=A&iddnssoa=#{id}&dominio=#{zone}&ip=no&tipoAccion=view"
      pdata.split('&').each do |p|
        key, val = p.split('=')
        params[key] = val
      end

      response = @agent.get("#{settings['app_url']}/GestionNavegacionDns", params)
      raise Exception.new('Invalid response from web server.') if response.code != '200'
      doc = Hpricot(response.parser.to_s)
      doc.search("//tr[@class='registros1']").each do |reg|
        fields = (reg/'td')
        a = ARecord.new
        a.id = fields[0].inner_text.strip.chomp
        a.name = fields[1].inner_text.gsub("?", "").strip.chomp + ".#{zone}"
        a.ip = fields[2].inner_text.strip.chomp
        domains << a
      end
      return domains
    end 

  end
end

