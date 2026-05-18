// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_hatchet_suppression.dart';

const _tracerName = 'dartastic_otel_libs_hatchet';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class HatchetResult {
  const HatchetResult({
    this.tenantId,
    this.workflowName,
    this.workflowRunId,
    this.stepRunId,
    this.stepName,
    this.workerId,
    this.queueName,
    this.runStatus,
    this.retryCount,
    this.priority,
    this.concurrencyKey,
    this.durationMs,
    this.statusCode,
  });

  /// Hatchet tenant — multi-tenant isolation boundary.
  final String? tenantId;

  final String? workflowName;
  final String? workflowRunId;
  final String? stepRunId;
  final String? stepName;

  /// Worker pod/process executing the step.
  final String? workerId;

  /// Queue name (Hatchet groups steps into named queues for routing).
  final String? queueName;

  /// `PENDING` / `RUNNING` / `SUCCEEDED` / `FAILED` / `CANCELLED` /
  /// `QUEUED` / `BACKOFF`.
  final String? runStatus;

  final int? retryCount;

  /// 1 (low) through 3 (high) — affects queue ordering.
  final int? priority;

  /// User-supplied key used by Hatchet's concurrency manager
  /// (e.g., tenant id, customer id).
  final String? concurrencyKey;

  final int? durationMs;
  final int? statusCode;
}

class HatchetCallResult<T> {
  const HatchetCallResult({required this.value, this.result});
  final T value;
  final HatchetResult? result;
}

/// Wraps a Hatchet API call in a CLIENT span. [operation] is one of
/// `workflow.trigger`, `workflow.run.cancel`, `workflow.run.replay`,
/// `step.run.get`, `worker.register`, `event.push`, `crons.create`.
Future<T> tracedHatchet<T>({
  required String operation,
  required Future<HatchetCallResult<T>> Function() invoke,
}) async {
  if (hatchetInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'hatchet',
    'rpc.method': operation,
    'hatchet.operation': operation,
  };

  final span = _tracer().startSpan(
    'hatchet $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.tenantId != null) {
        extras.add(OTel.attributeString(
          'hatchet.tenant.id',
          r.result!.tenantId!,
        ));
      }
      if (r.result!.workflowName != null) {
        extras.add(OTel.attributeString(
          'hatchet.workflow.name',
          r.result!.workflowName!,
        ));
      }
      if (r.result!.workflowRunId != null) {
        extras.add(OTel.attributeString(
          'hatchet.workflow_run.id',
          r.result!.workflowRunId!,
        ));
      }
      if (r.result!.stepRunId != null) {
        extras.add(OTel.attributeString(
          'hatchet.step_run.id',
          r.result!.stepRunId!,
        ));
      }
      if (r.result!.stepName != null) {
        extras.add(OTel.attributeString(
          'hatchet.step.name',
          r.result!.stepName!,
        ));
      }
      if (r.result!.workerId != null) {
        extras.add(OTel.attributeString(
          'hatchet.worker.id',
          r.result!.workerId!,
        ));
      }
      if (r.result!.queueName != null) {
        extras.add(OTel.attributeString(
          'hatchet.queue.name',
          r.result!.queueName!,
        ));
      }
      if (r.result!.runStatus != null) {
        extras.add(OTel.attributeString(
          'hatchet.run.status',
          r.result!.runStatus!,
        ));
        if (r.result!.runStatus == 'FAILED') {
          span.setStatus(SpanStatusCode.Error, 'Hatchet run FAILED');
        }
      }
      if (r.result!.retryCount != null) {
        extras.add(OTel.attributeInt(
          'hatchet.retry.count',
          r.result!.retryCount!,
        ));
      }
      if (r.result!.priority != null) {
        extras.add(OTel.attributeInt(
          'hatchet.priority',
          r.result!.priority!,
        ));
      }
      if (r.result!.concurrencyKey != null) {
        extras.add(OTel.attributeString(
          'hatchet.concurrency.key',
          r.result!.concurrencyKey!,
        ));
      }
      if (r.result!.durationMs != null) {
        extras.add(OTel.attributeInt(
          'hatchet.duration_ms',
          r.result!.durationMs!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Hatchet HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
