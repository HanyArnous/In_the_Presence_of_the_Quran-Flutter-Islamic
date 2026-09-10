import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:nabd/GlobalHelpers/constants.dart';

class AddTasbeehDialog extends StatefulWidget {
  Function function;

  AddTasbeehDialog({super.key, required this.function});

  @override
  State<AddTasbeehDialog> createState() => _AddTasbeehDialogState();
}

class _AddTasbeehDialogState extends State<AddTasbeehDialog> {
  TextEditingController textEditingController = TextEditingController();
  TextEditingController countController = TextEditingController(text: "33");
  bool enableSound = true;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(18.r),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 30.h,
          ),
          Text(
            "Add To Sibha".tr(),
            style: TextStyle(color: Colors.black, fontSize: 22.sp),
          ),
          SizedBox(
            height: 20.h,
          ),
          TextField(
            controller: textEditingController,
            onChanged: (ca) {},
            decoration: InputDecoration(hintText: "Enter Custom Zikr".tr()),
          ),
          SizedBox(
            height: 15.h,
          ),
          TextField(
            controller: countController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: "Default Count (optional)",
            ),
          ),
          SizedBox(
            height: 15.h,
          ),
          Row(
            children: [
              Checkbox(
                value: enableSound,
                onChanged: (value) {
                  setState(() {
                    enableSound = value ?? true;
                  });
                },
              ),
              Text(
                "Enable Sound",
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 16.sp,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 20.h,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              TextButton(
                  onPressed: () {
                    if (textEditingController.text.isEmpty) {
                    } else {
                      final count = int.tryParse(countController.text.trim());
                      widget.function(
                        textEditingController.text,
                        defaultCount: count,
                        enableSound: enableSound,
                      );
                    }
                  },
                  child: Text("Add".tr())),
              TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text("cancel".tr())),
            ],
          ),
          SizedBox(
            height: 30.h,
          ),
        ],
      ),
    );
  }
}
