import 'package:flutter/material.dart';
import '../../core/models/calendar_block.dart';

class EventCard extends StatelessWidget {
  const EventCard({super.key, required this.block});

  final CalendarBlock block;

  @override
  Widget build(BuildContext context) {
    final isLocal = block.source == EventSource.local;

    return Semantics(
      label: '${isLocal ? "Appointment" : "Google Event"}: '
          '${block.title}, '
          '${_formatTime(block.start)} to ${_formatTime(block.end)}, '
          '${block.duration.inMinutes} minutes',
      button: true,
      child: Container(
        decoration: BoxDecoration(
          color: block.displayColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: block.displayColor,
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isLocal ? Icons.event_rounded : Icons.calendar_today_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    block.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (block.subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                block.subtitle!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 2),
            Text(
              '${_formatTime(block.start)} - ${_formatTime(block.end)}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${dt.minute.toString().padLeft(2, '0')} $period';
  }
}