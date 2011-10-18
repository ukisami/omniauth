require 'omniauth/oauth'
require 'multi_json'
require 'digest/md5'
require 'net/http'

module OmniAuth
  module Strategies
    # Authenticate to Renren utilizing OAuth 2.0 and retrieve
    # basic user information.
    #
    # @example Basic Usage
    #   use OmniAuth::Strategies::Renren, 'client_id', 'client_secret'
    class Renren < OmniAuth::Strategies::OAuth2
      # @param [Rack Application] app standard middleware application parameter
      # @param [String] client_id the application id as [registered on Renren](http://dev.renren.com/)
      # @param [String] client_secret the application secret as registered on Renren
      # @option options [String] :scope ('publish_feed,status_update') comma-separated extended permissions such as `publish_feed` and `status_update`
      def initialize(app, client_id=nil, client_secret=nil, options={}, &block)
        client_options = {
          :authorize_url => 'https://graph.renren.com/oauth/authorize',
          :token_url => 'https://graph.renren.com/oauth/token',
          :site => "https://graph.renren.com/"
        }
        super(app, :renren, client_id, client_secret, client_options, options, &block)
      end

      def auth_hash
        OmniAuth::Utils.deep_merge(
          super, {
            'uid' => user_data['uid'],
            'user_info' => user_info,
            'extra' => {
              'user_hash' => user_data,
            },
          }
        )
      end

      def user_data
        @data ||= {
          'uid' => @access_token['user']['id'],
          'name' => @access_token['user']['name'],
          'profile_url' => @access_token['user']['avatar'].first['url']
        }
      end

      def signed_params
        params = {}
        params[:api_key] = client.id
        params[:method] = 'users.getInfo'
        params[:call_id] = Time.now.to_i
        params[:format] = 'json'
        params[:v] = '1.0'
        params[:uids] = session_key['user']['id']
        params[:session_key] = session_key['renren_token']['session_key']
        params[:sig] = Digest::MD5.hexdigest(params.map{|k,v| "#{k}=#{v}"}.sort.join + client.secret)
        params
      end

      def session_key
        @session_key ||= MultiJson.decode(@access_token.get("/renren_api/session_key?oauth_token=#{@access_token.token}").body)
      end

      def request_phase
        # options[:scope] ||= 'publish_feed'
        super
      end

      def build_access_token
        if renren_session.nil? || renrensession.empty?
          super
        else
          @access_token = ::OAuth2::AccessToken.new(client, renren_session['access_token'])
        end
      end

      def renren_session
        session_cookie = request.cookies["rrs_#{client.id}"]
        if session_cookie
          @renren_session ||= Rack::Utils.parse_query(request.cookies["rrs_#{client.id}"].gsub('"', ''))
        else
          nil
        end
      end

      def user_info
        {
          'username' => user_data['name'],
          'image' => user_data['profile_url']
        }
      end
    end
  end
end
