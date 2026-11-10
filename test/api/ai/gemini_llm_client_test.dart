import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:morkva_crm/api/ai/gemini_llm_client.dart';
import 'package:morkva_crm/api/ai/raw_function_declaration.dart';
import 'package:morkva_crm/core/agent/llm_client.dart';

/// A tool with every schema feature T0 checked: a closed object, a value
/// union (`anyOf`) and a free-form `values` map.
const _updateTool = LlmTool(
  name: 'cards_update',
  description: 'Plan an update of cards.',
  parametersJsonSchema: {
    'type': 'object',
    'additionalProperties': false,
    'required': ['collection', 'values'],
    'properties': {
      'collection': {'type': 'string'},
      'values': {
        'type': 'object',
        'additionalProperties': {
          'anyOf': [
            {'type': 'string'},
            {'type': 'number'},
            {'type': 'null'},
          ],
        },
      },
      'match': {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'limit': {'type': 'integer', 'minimum': 1, 'maximum': 500},
        },
      },
    },
  },
);

LlmRequest _request({
  List<LlmContent> contents = const [LlmUserText('How many orders?')],
  List<LlmTool> tools = const [_updateTool],
  LlmToolMode toolMode = LlmToolMode.auto,
  LlmThinking thinking = LlmThinking.off,
}) => LlmRequest(
  model: 'gemini-3.5-flash-lite',
  systemInstruction: 'You are Morkva.',
  contents: contents,
  tools: tools,
  toolMode: toolMode,
  thinking: thinking,
);

Map<String, Object?> _json(Object? Function() toJson) =>
    jsonDecode(jsonEncode(toJson())) as Map<String, Object?>;

void main() {
  group('RawFunctionDeclaration', () {
    test('sends the harness schema unchanged as parametersJsonSchema', () {
      final declaration = RawFunctionDeclaration(
        _updateTool.name,
        _updateTool.description,
        parametersJsonSchema: _updateTool.parametersJsonSchema,
      );

      expect(declaration.toJson(), {
        'name': 'cards_update',
        'description': 'Plan an update of cards.',
        'parametersJsonSchema': _updateTool.parametersJsonSchema,
      });
      expect(Tool.functionDeclarations([declaration]).toJson(), {
        'functionDeclarations': [declaration.toJson()],
      });
    });

    test('can strip closed objects, keeping value maps', () {
      final schema = RawFunctionDeclaration(
        'x',
        'y',
        parametersJsonSchema: _updateTool.parametersJsonSchema,
        stripClosedObjects: true,
      ).toJson()['parametersJsonSchema'];

      final encoded = jsonEncode(schema);
      expect(encoded, isNot(contains('"additionalProperties":false')));
      expect(
        (((schema as Map)['properties'] as Map)['values']
            as Map)['additionalProperties'],
        isA<Map<String, Object?>>(),
      );
      expect(
        ((schema['properties'] as Map)['match'] as Map)['properties'],
        isNotNull,
      );
    });
  });

  group('buildCall', () {
    final client = GeminiLlmClient(open: (_) => const Stream.empty());

    test('builds the model, tools and generation settings', () {
      final call = client.buildCall(_request());

      expect(call.model, 'gemini-3.5-flash-lite');
      expect(_json(call.systemInstruction.toJson), {
        'role': 'system',
        'parts': [
          {'text': 'You are Morkva.'},
        ],
      });
      expect(_json(call.tools.single.toJson), {
        'functionDeclarations': [
          {
            'name': 'cards_update',
            'description': 'Plan an update of cards.',
            'parametersJsonSchema': _updateTool.parametersJsonSchema,
          },
        ],
      });
      expect(call.toolConfig!.toJson(), {
        'functionCallingConfig': {'mode': 'AUTO'},
      });
      expect(_json(call.generationConfig.toJson), {
        'temperature': 0.2,
        'maxOutputTokens': 2048,
        'thinkingConfig': {
          'thinkingLevel': 'MINIMAL',
          'includeThoughts': false,
        },
      });
    });

    test('maps tool modes, with "any" allowing every declared tool', () {
      expect(
        client
            .buildCall(_request(toolMode: LlmToolMode.none))
            .toolConfig!
            .toJson(),
        {
          'functionCallingConfig': {'mode': 'NONE'},
        },
      );
      expect(
        client
            .buildCall(_request(toolMode: LlmToolMode.any))
            .toolConfig!
            .toJson(),
        {
          'functionCallingConfig': {
            'mode': 'ANY',
            'allowedFunctionNames': ['cards_update'],
          },
        },
      );
    });

    test('declares no tools and no tool config when there are none', () {
      final call = client.buildCall(_request(tools: const []));

      expect(call.tools, isEmpty);
      expect(call.toolConfig, isNull);
    });

    test('thinking is a level on 3.x and a budget on 2.x models', () {
      expect(
        thinkingConfig('gemini-3.5-flash-lite', LlmThinking.low).toJson(),
        {'thinkingLevel': 'LOW', 'includeThoughts': false},
      );
      expect(thinkingConfig('gemini-2.5-flash', LlmThinking.off).toJson(), {
        'thinkingBudget': 0,
        'includeThoughts': false,
      });
      expect(thinkingConfig('gemini-2.5-flash', LlmThinking.low).toJson(), {
        'thinkingBudget': 512,
        'includeThoughts': false,
      });
      expect(
        _json(
          client
              .buildCall(_request(thinking: LlmThinking.medium))
              .generationConfig
              .toJson,
        )['maxOutputTokens'],
        4096,
      );
    });

    test('converts the conversation, echoing Gemini call ids', () {
      final modelTurn = Content.model([
        FunctionCall.forTest(
          'cards_update',
          const {'collection': 'Orders'},
          id: 'call_1',
          thoughtSignature: 'sig-1',
        ),
      ]);

      final call = client.buildCall(
        _request(
          contents: [
            const LlmUserText('Mark them paid'),
            LlmModelContent(modelTurn),
            const LlmFunctionResponses([
              LlmFunctionResponse(
                name: 'cards_update',
                response: {'status': 'applied', 'applied': 3},
                geminiId: 'call_1',
              ),
              LlmFunctionResponse(name: 'ui_open', response: {'ok': true}),
            ]),
            // An empty model turn (a blocked response) is never sent.
            LlmModelContent(Content.model(const [])),
          ],
        ),
      );

      expect(call.contents, hasLength(3));
      expect(call.contents[1], same(modelTurn));
      expect(_json(call.contents[2].toJson), {
        'role': 'function',
        'parts': [
          {
            'functionResponse': {
              'name': 'cards_update',
              'response': {'status': 'applied', 'applied': 3},
              'id': 'call_1',
            },
          },
          {
            'functionResponse': {
              'name': 'ui_open',
              'response': {'ok': true},
            },
          },
        ],
      });
    });
  });

  group('encodeContent', () {
    final client = GeminiLlmClient(open: (_) => const Stream.empty());

    test('a model turn survives persistence with its thought signature', () {
      final model = LlmModelContent(
        Content.model([
          FunctionCall.forTest(
            'cards_query',
            const {
              'collection': 'Orders',
              'sort': [
                ['Total', 'desc'],
              ],
              'values': {'': 'empty key'},
            },
            id: 'call_9',
            thoughtSignature: 'sig-9',
          ),
          const TextPart('Done.'),
        ]),
      );

      // Persisted as one jsonEncode string, restored as LlmRawContent.
      final stored = jsonEncode(client.encodeContent(model));
      final restored = LlmRawContent(
        jsonDecode(stored) as Map<String, Object?>,
      );

      expect(client.encodeContent(restored), restored.json);
      final replayed = client.buildCall(_request(contents: [restored]));
      final parts = _json(replayed.contents.single.toJson)['parts'] as List;
      expect(parts.first, containsPair('thoughtSignature', 'sig-9'));
      final original = _json((model.opaque as Content).toJson)['parts'] as List;
      expect(
        (parts.first as Map)['functionCall'],
        (original.first as Map)['functionCall'],
      );
      expect(replayed.contents.single.role, 'model');
    });

    test('user text and function responses encode as Gemini JSON', () {
      expect(client.encodeContent(const LlmUserText('Hi')), {
        'role': 'user',
        'parts': [
          {'text': 'Hi'},
        ],
      });
      expect(
        _json(
          () => client.encodeContent(
            const LlmFunctionResponses([
              LlmFunctionResponse(name: 'a', response: {'n': 1}, geminiId: 'x'),
            ]),
          ),
        ),
        {
          'role': 'function',
          'parts': [
            {
              'functionResponse': {
                'name': 'a',
                'response': {'n': 1},
                'id': 'x',
              },
            },
          ],
        },
      );
    });
  });

  group('generate', () {
    test('streams the aggregated response of the call it built', () async {
      GeminiCall? sent;
      final client = GeminiLlmClient(
        open: (call) {
          sent = call;
          return Stream.fromIterable([
            GenerateContentResponse([
              Candidate(
                Content.model([const TextPart('12 orders.')]),
                null,
                null,
                FinishReason.stop,
                null,
              ),
            ], null),
          ]);
        },
      );

      final chunks = await client.generate(_request()).toList();

      expect(sent!.model, 'gemini-3.5-flash-lite');
      expect(chunks.map((c) => c.runtimeType), [
        LlmText,
        LlmModelContent,
        LlmFinish,
      ]);
    });

    test('a failure to open the request ends the stream with a failure', () {
      final client = GeminiLlmClient(
        open: (_) => throw http.ClientException('offline'),
      );

      expect(client.generate(_request()), emitsError(isA<LlmTransient>()));
    });

    test('Stop cancels the request', () async {
      var cancelled = false;
      final response = StreamController<GenerateContentResponse>(
        onCancel: () {
          cancelled = true;
          throw http.ClientException('Connection closed');
        },
      );
      final client = GeminiLlmClient(open: (_) => response.stream);

      final subscription = client.generate(_request()).listen((_) {});
      await pumpEventQueue();
      await subscription.cancel();

      expect(cancelled, isTrue);
    });
  });
}
