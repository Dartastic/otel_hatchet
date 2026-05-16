// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_hatchet/otel_hatchet.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_hatchet-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('workflow.trigger records tenant + workflow + concurrency', () async {
    await tracedHatchet<String>(
      operation: 'workflow.trigger',
      invoke: () async => const HatchetCallResult(
        value: 'ok',
        result: HatchetResult(
          tenantId: 'tenant_a',
          workflowName: 'process-invoice',
          workflowRunId: 'wfr_1',
          queueName: 'invoicing',
          runStatus: 'QUEUED',
          priority: 2,
          concurrencyKey: 'customer:42',
          statusCode: 200,
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('hatchet workflow.trigger')!);
    expect(a['hatchet.tenant.id'], 'tenant_a');
    expect(a['hatchet.workflow.name'], 'process-invoice');
    expect(a['hatchet.queue.name'], 'invoicing');
    expect(a['hatchet.concurrency.key'], 'customer:42');
    expect(a['hatchet.priority'], 2);
  });

  test('FAILED run sets span error', () async {
    await tracedHatchet<String>(
      operation: 'step.run.get',
      invoke: () async => const HatchetCallResult(
        value: 'ok',
        result: HatchetResult(
          runStatus: 'FAILED',
          retryCount: 3,
          durationMs: 2500,
        ),
      ),
    );
    expect(
      spans.findSpanByName('hatchet step.run.get')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutHatchetInstrumentationAsync(() async {
      await tracedHatchet<String>(
        operation: 'event.push',
        invoke: () async => const HatchetCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('hatchet '), isEmpty);
  });
}
