import 'dart:io';
import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://gbcjixxmxfjldfbwwxvm.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdiY2ppeHhteGZqbGRmYnd3eHZtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzNDQyNzYsImV4cCI6MjA5MTkyMDI3Nn0.RPbo_pwzJbmWfq38hvZbHRWx_qxhejFR4NvNyjrQbHw'
  );

  try {
    final res = await supabase.from('installments').insert({
      'loan_id': '2fb7a8f9-cbe9-4b17-be76-783cd0cd88b8',
      'expected_principal': 100.0,
      'expected_interest': 20.0,
      'due_date': '2026-04-20'
    });
    print('SUCCESS: $res');
  } catch (e) {
    print('ERROR: $e');
  }
}
