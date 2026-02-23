# frozen_string_literal: true

module RubyLLM
  module Providers
    # HuggingFace Inference Providers API integration.
    # Uses the OpenAI-compatible router at https://router.huggingface.co/v1
    # for chat completions and the HF Inference API for embeddings and images.
    class HuggingFace < OpenAI
      include HuggingFace::Chat

      def api_base
        'https://router.huggingface.co/v1'
      end

      def headers
        { 'Authorization' => "Bearer #{@config.hugging_face_api_key}" }
      end

      class << self
        def slug
          'hugging_face'
        end

        def configuration_requirements
          %i[hugging_face_api_key]
        end

        # HuggingFace hosts thousands of models that can't be pre-enumerated.
        # Users pass model IDs directly (e.g. "meta-llama/Llama-3.1-8B-Instruct").
        def assume_models_exist?
          true
        end
      end
    end
  end
end
