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

module NocDns
  class InvalidSettingsException < Exception; end
  class InvalidZoneException < Exception; end

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

    def list_domains(zone=nil)
      domains = []
      if zone.nil? or zone.strip.chomp.empty?
        zones = available_zones.keys
      else
        zones = [zone]
      end
      zones.each do |z|
        domains.concat list_zone_domains(z)
      end
      return domains
    end

    def find(exp)
      findings = []
      list_domains.each do |d|
        findings << d if d =~ /#{exp}/
      end
      return findings
    end

    private
    def list_zone_domains(zone)
      if not available_zones.has_key? zone
        raise InvalidZoneException.new("zone mapping not found for #{zone}")
      end
      domains = []
      params = {}
      id = available_zones[zone]
      pdata = "pagina=A&iddnssoa=#{id}&dominio=#{zone}&ip=no&tipoAccion=adm"
      pdata.split('&').each do |p|
        key, val = p.split('=')
        params[key] = val
      end

      response = @agent.get("#{settings['app_url']}/GestionNavegacionDns", params)
      raise Exception.new('Invalid response from web server.') if response.code != '200'
      doc = Hpricot(response.parser.to_s)
      doc.search("//tr[@class='registros2']").each do |reg|
        text = (reg/'td').inner_text.chomp.strip
        if not text.empty?
          d,i = text.split[1..-1]
          fqdn = "#{d}.#{zone}".ljust(50)
          domains << "#{fqdn} #{i}"
        end
      end
      return domains
    end 

  end
end

