import 'package:flutter/material.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/buttons/app_icon_button.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/selects/app_select.dart';
import '../../../components/shared/app_variant.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _controller = TextEditingController();
  String? _selectValue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Componentes Globais')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Buttons'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppButton(label: 'Primary', onPressed: () {}, variant: AppVariant.primary),
              AppButton(label: 'Success', onPressed: () {}, variant: AppVariant.success),
              AppButton(label: 'Warning', onPressed: () {}, variant: AppVariant.warning),
              AppButton(label: 'Danger', onPressed: () {}, variant: AppVariant.danger),
              AppButton(label: 'Ghost', onPressed: () {}, transparent: true),
              AppButton(label: 'Loading', onPressed: () {}, isLoading: true),
              AppButton(label: 'Disabled', onPressed: null, isDisabled: true),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Icon Buttons'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              AppIconButton(icon: Icons.play_arrow_rounded, onPressed: () {}, variant: AppVariant.success),
              AppIconButton(icon: Icons.stop_rounded, onPressed: () {}, variant: AppVariant.danger),
              AppIconButton(icon: Icons.info_outline_rounded, onPressed: () {}, transparent: true),
            ],
          ),
          const SizedBox(height: 16),
          AppTextInput(
            label: 'Comando',
            hint: 'Digite um comando',
            controller: _controller,
            prefixIcon: const Icon(Icons.terminal_rounded),
          ),
          const SizedBox(height: 16),
          AppSelect<String>(
            label: 'Ambiente',
            value: _selectValue,
            items: const [
              AppSelectItem(value: 'local', label: 'Local'),
              AppSelectItem(value: 'test', label: 'Teste'),
            ],
            onChanged: (value) => setState(() => _selectValue = value),
          ),
        ],
      ),
    );
  }
}
