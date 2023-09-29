import 'package:flutter/material.dart';
import 'package:the_bottle/components/dialog/options_modal_bottom_sheet.dart';
import 'package:the_bottle/firebase/conversation/conversation_controller.dart';
import 'package:the_bottle/pages/conversation_page.dart';
import 'package:the_bottle/pages/conversations_page.dart';

class DrawerConversations extends StatelessWidget {
  const DrawerConversations({super.key});

  @override
  Widget build(BuildContext context) {
    Future<void> onConversationTileLongPress(String conversationId) async {
      ConversationController conversationController = ConversationController(
        conversationId: conversationId,
        setStateCallback: (_) {},
        context: context,
        itemScrollController: null,
      );
      await conversationController.initController();
      // ignore: use_build_context_synchronously
      await optionsFromModalBottomSheet(
        context,
        children: [
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete Conversation'),
            onTap: () {
              conversationController.deleteConversationIfEmpty(forceDelete: true);
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    }

    Future<void> onConversationTileTap(String conversationId) async {
      // go to conversation
      Navigator.pop(context);
      Navigator.of(context).popUntil((route) => route.isFirst);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ConversationPage(
            conversationId: conversationId,
          ),
        ),
      );
    }

    return Drawer(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: ConversationsPage(
          onConversationTileTap: onConversationTileTap,
          onConversationTileLongPress: onConversationTileLongPress,
        ),
      ),
    );
  }
}
