import 'package:app_flowy/generated/locale_keys.g.dart';
import 'package:app_flowy/plugins/grid/application/cell/date_cal_bloc.dart';
import 'package:app_flowy/plugins/grid/application/field/type_option/type_option_context.dart';
import 'package:appflowy_popover/appflowy_popover.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flowy_infra/image.dart';
import 'package:flowy_infra/theme.dart';
import 'package:flowy_infra_ui/flowy_infra_ui.dart';
import 'package:flowy_infra_ui/style_widget/button.dart';
import 'package:flowy_infra_ui/style_widget/text.dart';
import 'package:flowy_infra_ui/widget/rounded_input_field.dart';
import 'package:flowy_infra_ui/widget/spacing.dart';
import 'package:flowy_sdk/log.dart';
import 'package:flowy_sdk/protobuf/flowy-grid/date_type_option.pb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:app_flowy/plugins/grid/application/prelude.dart';
import '../../../layout/sizes.dart';
import '../../header/type_option/date.dart';

final kToday = DateTime.now();
final kFirstDay = DateTime(kToday.year, kToday.month - 3, kToday.day);
final kLastDay = DateTime(kToday.year, kToday.month + 3, kToday.day);
const kMargin = EdgeInsets.symmetric(horizontal: 6, vertical: 10);

class DateCellEditor extends StatefulWidget {
  final VoidCallback onDismissed;
  final GridDateCellController cellController;

  const DateCellEditor({
    Key? key,
    required this.onDismissed,
    required this.cellController,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _DateCellEditor();
}

class _DateCellEditor extends State<DateCellEditor> {
  DateTypeOptionPB? _dateTypeOptionPB;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  _fetchData() async {
    final result = await widget.cellController
        .getFieldTypeOption(DateTypeOptionDataParser());

    result.fold((dateTypeOptionPB) {
      setState(() {
        _dateTypeOptionPB = dateTypeOptionPB;
      });
    }, (err) => Log.error(err));
  }

  @override
  Widget build(BuildContext context) {
    if (_dateTypeOptionPB == null) {
      return Container();
    }

    return _CellCalendarWidget(
      cellContext: widget.cellController,
      dateTypeOptionPB: _dateTypeOptionPB!,
    );
  }
}

class _CellCalendarWidget extends StatelessWidget {
  final GridDateCellController cellContext;
  final DateTypeOptionPB dateTypeOptionPB;

  const _CellCalendarWidget({
    required this.cellContext,
    required this.dateTypeOptionPB,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();
    return BlocProvider(
      create: (context) {
        return DateCalBloc(
          dateTypeOptionPB: dateTypeOptionPB,
          cellData: cellContext.getCellData(),
          cellController: cellContext,
        )..add(const DateCalEvent.initial());
      },
      child: BlocBuilder<DateCalBloc, DateCalState>(
        buildWhen: (p, c) => false,
        builder: (context, state) {
          List<Widget> children = [
            _buildCalendar(theme, context),
            _TimeTextField(bloc: context.read<DateCalBloc>()),
            Divider(height: 1, color: theme.shader5),
            const _IncludeTimeButton(),
            const _DateTypeOptionButton()
          ];

          return ListView.separated(
            shrinkWrap: true,
            controller: ScrollController(),
            separatorBuilder: (context, index) {
              return VSpace(GridSize.typeOptionSeparatorHeight);
            },
            itemCount: children.length,
            itemBuilder: (BuildContext context, int index) {
              return children[index];
            },
          );
        },
      ),
    );
  }

  Widget _buildCalendar(AppTheme theme, BuildContext context) {
    return BlocBuilder<DateCalBloc, DateCalState>(
      builder: (context, state) {
        return TableCalendar(
          firstDay: kFirstDay,
          lastDay: kLastDay,
          focusedDay: state.focusedDay,
          rowHeight: 40,
          calendarFormat: state.format,
          headerStyle: HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
            leftChevronMargin: EdgeInsets.zero,
            leftChevronPadding: EdgeInsets.zero,
            leftChevronIcon: svgWidget("home/arrow_left"),
            rightChevronPadding: EdgeInsets.zero,
            rightChevronMargin: EdgeInsets.zero,
            rightChevronIcon: svgWidget("home/arrow_right"),
          ),
          calendarStyle: CalendarStyle(
            selectedDecoration: BoxDecoration(
              color: theme.main1,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: theme.shader4,
              shape: BoxShape.circle,
            ),
            selectedTextStyle: TextStyle(
              color: theme.surface,
              fontSize: 14.0,
            ),
            todayTextStyle: TextStyle(
              color: theme.surface,
              fontSize: 14.0,
            ),
          ),
          selectedDayPredicate: (day) {
            return state.calData.fold(
              () => false,
              (dateData) => isSameDay(dateData.date, day),
            );
          },
          onDaySelected: (selectedDay, focusedDay) {
            context
                .read<DateCalBloc>()
                .add(DateCalEvent.selectDay(selectedDay));
          },
          onFormatChanged: (format) {
            context.read<DateCalBloc>().add(DateCalEvent.setCalFormat(format));
          },
          onPageChanged: (focusedDay) {
            context
                .read<DateCalBloc>()
                .add(DateCalEvent.setFocusedDay(focusedDay));
          },
        );
      },
    );
  }
}

class _IncludeTimeButton extends StatelessWidget {
  const _IncludeTimeButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();
    return BlocSelector<DateCalBloc, DateCalState, bool>(
      selector: (state) => state.dateTypeOptionPB.includeTime,
      builder: (context, includeTime) {
        return SizedBox(
          height: 50,
          child: Padding(
            padding: kMargin,
            child: Row(
              children: [
                svgWidget("grid/clock", color: theme.iconColor),
                const HSpace(4),
                FlowyText.medium(LocaleKeys.grid_field_includeTime.tr(),
                    fontSize: 14),
                const Spacer(),
                Switch(
                  value: includeTime,
                  onChanged: (newValue) => context
                      .read<DateCalBloc>()
                      .add(DateCalEvent.setIncludeTime(newValue)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TimeTextField extends StatefulWidget {
  final DateCalBloc bloc;
  const _TimeTextField({
    required this.bloc,
    Key? key,
  }) : super(key: key);

  @override
  State<_TimeTextField> createState() => _TimeTextFieldState();
}

class _TimeTextFieldState extends State<_TimeTextField> {
  late final FocusNode _focusNode;
  late final TextEditingController _controller;

  @override
  void initState() {
    _focusNode = FocusNode();
    _controller = TextEditingController(text: widget.bloc.state.time);
    if (widget.bloc.state.dateTypeOptionPB.includeTime) {
      _focusNode.addListener(() {
        if (mounted) {
          widget.bloc.add(DateCalEvent.setTime(_controller.text));
        }
      });
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();
    return BlocConsumer<DateCalBloc, DateCalState>(
      listener: (context, state) {
        _controller.text = state.time ?? "";
      },
      listenWhen: (p, c) => p.time != c.time,
      builder: (context, state) {
        if (state.dateTypeOptionPB.includeTime) {
          return Padding(
            padding: kMargin,
            child: RoundedInputField(
              height: 40,
              focusNode: _focusNode,
              autoFocus: true,
              hintText: state.timeHintText,
              controller: _controller,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              normalBorderColor: theme.shader4,
              errorBorderColor: theme.red,
              focusBorderColor: theme.main1,
              cursorColor: theme.main1,
              errorText: state.timeFormatError.fold(() => "", (error) => error),
              onEditingComplete: (value) {
                widget.bloc.add(DateCalEvent.setTime(value));
              },
            ),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }
}

class _DateTypeOptionButton extends StatelessWidget {
  const _DateTypeOptionButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppTheme>();
    final title =
        "${LocaleKeys.grid_field_dateFormat.tr()} &${LocaleKeys.grid_field_timeFormat.tr()}";
    return BlocSelector<DateCalBloc, DateCalState, DateTypeOptionPB>(
      selector: (state) => state.dateTypeOptionPB,
      builder: (context, dateTypeOptionPB) {
        return AppFlowyPopover(
          triggerActions: PopoverTriggerFlags.hover | PopoverTriggerFlags.click,
          offset: const Offset(20, 0),
          constraints: BoxConstraints.loose(const Size(140, 100)),
          child: FlowyButton(
            text: FlowyText.medium(title, fontSize: 12),
            hoverColor: theme.hover,
            margin: kMargin,
            rightIcon: svgWidget("grid/more", color: theme.iconColor),
          ),
          popupBuilder: (BuildContext popContext) {
            return _CalDateTimeSetting(
              dateTypeOptionPB: dateTypeOptionPB,
              onEvent: (event) => context.read<DateCalBloc>().add(event),
            );
          },
        );
      },
    );
  }
}

class _CalDateTimeSetting extends StatefulWidget {
  final DateTypeOptionPB dateTypeOptionPB;
  final Function(DateCalEvent) onEvent;
  const _CalDateTimeSetting(
      {required this.dateTypeOptionPB, required this.onEvent, Key? key})
      : super(key: key);

  @override
  State<_CalDateTimeSetting> createState() => _CalDateTimeSettingState();
}

class _CalDateTimeSettingState extends State<_CalDateTimeSetting> {
  String? overlayIdentifier;
  final _popoverMutex = PopoverMutex();

  @override
  Widget build(BuildContext context) {
    List<Widget> children = [
      AppFlowyPopover(
        mutex: _popoverMutex,
        asBarrier: true,
        triggerActions: PopoverTriggerFlags.hover | PopoverTriggerFlags.click,
        offset: const Offset(20, 0),
        popupBuilder: (BuildContext context) {
          return DateFormatList(
            selectedFormat: widget.dateTypeOptionPB.dateFormat,
            onSelected: (format) =>
                widget.onEvent(DateCalEvent.setDateFormat(format)),
          );
        },
        child: const DateFormatButton(),
      ),
      AppFlowyPopover(
        mutex: _popoverMutex,
        asBarrier: true,
        triggerActions: PopoverTriggerFlags.hover | PopoverTriggerFlags.click,
        offset: const Offset(20, 0),
        popupBuilder: (BuildContext context) {
          return TimeFormatList(
            selectedFormat: widget.dateTypeOptionPB.timeFormat,
            onSelected: (format) =>
                widget.onEvent(DateCalEvent.setTimeFormat(format)),
          );
        },
        child: TimeFormatButton(timeFormat: widget.dateTypeOptionPB.timeFormat),
      ),
    ];

    return SizedBox(
      width: 180,
      child: ListView.separated(
        shrinkWrap: true,
        controller: ScrollController(),
        separatorBuilder: (context, index) {
          return VSpace(GridSize.typeOptionSeparatorHeight);
        },
        itemCount: children.length,
        itemBuilder: (BuildContext context, int index) {
          return children[index];
        },
      ),
    );
  }
}
