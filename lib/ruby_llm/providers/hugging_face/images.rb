# frozen_string_literal: true

module RubyLLM
  module Providers
    class HuggingFace
      # Image generation for the HuggingFace Inference Providers API.
      # Uses the HF Inference API endpoint which returns raw binary image bytes,
      # not the OpenAI-compatible router used for chat.
      module Images
        IMAGE_API_BASE = 'https://router.huggingface.co/hf-inference/models'

        def paint(prompt, model:, size:)
          width, height = parse_size(size)

          parameters = { width: width, height: height }.compact
          payload = { inputs: prompt, parameters: parameters }.to_json

          response = Connection.basic do |f|
            f.adapter :net_http
          end.post("#{IMAGE_API_BASE}/#{model}") do |req|
            req.headers['Authorization'] = "Bearer #{@config.hugging_face_api_key}"
            req.headers['Content-Type'] = 'application/json'
            req.headers['Accept'] = 'image/png, image/jpeg, image/webp, image/gif, image/bmp, image/tiff'
            req.body = payload
          end

          mime_type = response.headers['content-type']&.split(';')&.first || 'image/jpeg'

          Image.new(
            data: Base64.strict_encode64(response.body),
            mime_type: mime_type,
            model_id: model
          )
        end

        private

        def parse_size(size)
          return [nil, nil] unless size

          parts = size.to_s.split('x')
          return [nil, nil] unless parts.length == 2

          [Integer(parts[0]), Integer(parts[1])]
        rescue ArgumentError
          [nil, nil]
        end
      end
    end
  end
end
