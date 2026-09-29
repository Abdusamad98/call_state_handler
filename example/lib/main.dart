import 'package:call_state_handler/call_state_handler.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MaterialApp(home: CallMonitorPage()));

class CallMonitorPage extends StatefulWidget {
  const CallMonitorPage({super.key});

  @override
  State<CallMonitorPage> createState() => _CallMonitorPageState();
}

class _CallMonitorPageState extends State<CallMonitorPage> {
  final CallStateHandler _handler = CallStateHandler();
  bool _voipEnabled = true;

  @override
  void initState() {
    super.initState();
    _handler.initialize();
  }

  @override
  void dispose() {
    _handler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('call_state_handler')),
      body: StreamBuilder<CallState>(
        stream: _handler.onCallStateChanged,
        initialData: _handler.currentState,
        builder: (context, snapshot) {
          final state = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: state.isCallActive
                      ? Colors.red.shade100
                      : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  state.isCallActive
                      ? 'Call active: ${state.callType.name}'
                      : 'No active call',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              SwitchListTile(
                title: const Text('VoIP/video detection (Android)'),
                value: _voipEnabled,
                onChanged: (value) {
                  setState(() => _voipEnabled = value);
                  _handler.setVoipDetectionEnabled(value);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
