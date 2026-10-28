// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_hatchet/otel_hatchet.dart';

/// Traces Hatchet calls with OpenTelemetry.
///
/// `otel_hatchet` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each Hatchet call in
/// [tracedHatchet]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'hatchet-example');

  // Wraps a Hatchet API call in a CLIENT span.
  final hatchetId = await tracedHatchet<String>(
    operation: 'crons.create',
    invoke: () async {
      // Make the Hatchet call here, then report what it returned.
      const id = 'hatchet_8f3a2c';
      return const HatchetCallResult(
          value: id,
          result: HatchetResult(
              tenantId: 'tenant_8f3a2c',
              workflowName: 'example',
              workflowRunId: 'workflowrun_8f3a2c',
              stepRunId: 'steprun_8f3a2c',
              stepName: 'example',
              workerId: 'worker_8f3a2c',
              queueName: 'orders',
              runStatus: 'PENDING',
              retryCount: 3,
              priority: 1,
              concurrencyKey: 'usd',
              durationMs: 120,
              statusCode: 201));
    },
  );
  OTelLog.info('tracedHatchet crons.create returned $hatchetId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutHatchetInstrumentationAsync.
  await runWithoutHatchetInstrumentationAsync(
    () => tracedHatchet<String>(
      operation: 'crons.create',
      invoke: () async {
        const id = 'hatchet_8f3a2c';
        return const HatchetCallResult(
            value: id,
            result: HatchetResult(
                tenantId: 'tenant_8f3a2c',
                workflowName: 'example',
                workflowRunId: 'workflowrun_8f3a2c',
                stepRunId: 'steprun_8f3a2c',
                stepName: 'example',
                workerId: 'worker_8f3a2c',
                queueName: 'orders',
                runStatus: 'PENDING',
                retryCount: 3,
                priority: 1,
                concurrencyKey: 'usd',
                durationMs: 120,
                statusCode: 201));
      },
    ),
  );

  await OTel.shutdown();
}
