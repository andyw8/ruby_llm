# frozen_string_literal: true

module RubyLLM
  module Providers
    class HuggingFace
      # Chat methods for the HuggingFace Inference Providers API.
      # HF model IDs use the "owner/repo" format (e.g. "meta-llama/Llama-3.1-8B-Instruct")
      # and can include a routing policy suffix: ":fastest", ":cheapest", ":preferred",
      # or a specific backend name like ":sambanova".
      module Chat
        module_function

        def format_role(role)
          role.to_s
        end

        def render_payload(messages, tools:, temperature:, model:, stream: false, schema: nil, thinking: nil) # rubocop:disable Metrics/ParameterLists,Lint/UnusedMethodArgument
          payload = {
            model: model.id,
            messages: format_messages(messages),
            stream: stream
          }

          payload[:temperature] = temperature unless temperature.nil?
          payload[:tools] = tools.map { |_, tool| OpenAI::Tools.tool_for(tool) } if tools.any?

          if schema
            strict = schema[:strict] != false
            payload[:response_format] = {
              type: 'json_schema',
              json_schema: {
                name: 'response',
                schema: schema,
                strict: strict
              }
            }
          end

          payload[:stream_options] = { include_usage: true } if stream
          payload
        end

        def format_messages(messages)
          messages.map do |msg|
            {
              role: format_role(msg.role),
              content: OpenAI::Media.format_content(msg.content),
              tool_calls: OpenAI::Tools.format_tool_calls(msg.tool_calls),
              tool_call_id: msg.tool_call_id
            }.compact
          end
        end
      end
    end
  end
end
