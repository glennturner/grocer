require 'json'

module Grocer
  # Public: An object used to send notifications to APNS.
  class Notification
    MAX_PAYLOAD_SIZE = 2048
    CONTENT_AVAILABLE_INDICATOR = 1
    DEFAULT_PRIORITY = 10

    attr_accessor :identifier, :expiry, :device_token
    attr_reader :alert, :badge, :custom, :sound, :content_available, :priority, :category

    # Public: Initialize a new Grocer::Notification. You must specify at least an `alert` or `badge`.
    #
    # payload - The Hash of notification parameters and payload to be sent to APNS.:
    #           :device_token      - The String representing to device token sent to APNS.
    #           :alert             - The String or Hash to be sent as the alert portion of the payload. (optional)
    #           :badge             - The Integer to be sent as the badge portion of the payload. (optional)
    #           :sound             - The String representing the sound portion of the payload. (optional)
    #           :expiry            - The Integer representing UNIX epoch date sent to APNS as the notification expiry. (default: 0)
    #           :identifier        - The arbitrary Integer sent to APNS to uniquely this notification. (default: 0)
    #           :priority					 - The priority level for the message. (default: 10)
    #           :content_available - The truthy or falsy value indicating the availability of new content for background fetch. (optional)
    #           :category          - The String to be sent as the category portion of the payload. (optional)
    def initialize(payload = {})
      @identifier = 0

      payload.each do |key, val|
        send("#{key}=", val)
      end
    end

    def to_bytes_legacy
      validate_payload

      [
        1, 
        identifier,
        expiry_epoch_time,
        device_token_length,
        sanitized_device_token,
        encoded_payload.bytesize,
        encoded_payload
      ].pack('CNNnH64nA*')
    end
    
		def to_bytes
      validate_payload
			
      bytes = [
        2,
        item_frames_length
      ].pack('CN')
      bytes += item_frames
      
      bytes      
		end
		
		def item_frames_length			
			@frames.bytesize
		end

		def item_frames
			@frames = [
				1, 
        device_token_length, 
        sanitized_device_token, 
        2,
        encoded_payload.bytesize,
        encoded_payload,
        3,
        identifier_length,
        identifier,
        4,
				expiry_epoch_time_length,
			  expiry_epoch_time,
			  5,
			  priority_length,
			  10
      ]
            
      @frames = @frames.pack( 'CnH64CnA*CnNCnNCnC' )
		end

    def alert=(alert)
      @alert = alert
      @encoded_payload = nil
    end

    def badge=(badge)
      @badge = badge
      @encoded_payload = nil
    end

    def custom=(custom)
      @custom = custom
      @encoded_payload = nil
    end

    def sound=(sound)
      @sound = sound
      @encoded_payload = nil
    end

    def category=(category)
      @category = category
      @encoded_payload = nil
    end
    
    def priority=(priority)
      @priority = DEFAULT_PRIORITY ? priority : DEFAULT_PRIORITY
      @encoded_payload = nil
    end

    def content_available=(content_available)
      @content_available = CONTENT_AVAILABLE_INDICATOR if content_available
      @encoded_payload = nil
    end

    def content_available?
      !!content_available
    end

    def validate_payload
      fail NoPayloadError unless alert || badge || custom
      fail PayloadTooLargeError if payload_too_large?
      true
    end

    def valid?
      validate_payload rescue false
    end

    private

    def encoded_payload
      @encoded_payload ||= JSON.dump(payload_hash)
    end

    def payload_hash
      aps_hash = { }
      aps_hash[:alert] = alert if alert
      aps_hash[:badge] = badge if badge
      aps_hash[:sound] = sound if sound
      aps_hash[:'content-available'] = content_available if content_available?
      aps_hash[:category] = category if category

      { aps: aps_hash }.merge(custom || { })
    end

    def payload_too_large?
      encoded_payload.bytesize > MAX_PAYLOAD_SIZE
    end

    def expiry_epoch_time
      expiry.to_i
    end

    def sanitized_device_token
      device_token.tr(' ', '') if device_token
    end
    
    def sanitized_priority
    	@priority == 10 ? @priority : DEFAULT_PRIORITY
    end

    def device_token_length
      32
    end

		def expiry_epoch_time_length
			4
		end

		def identifier_length
			4
		end

		def priority_length
			1
		end
  end
end
