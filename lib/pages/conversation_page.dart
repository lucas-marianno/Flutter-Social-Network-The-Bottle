import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:the_wall/components/drawer_conversation.dart';
import 'package:the_wall/components/input_field.dart';
import 'package:the_wall/util/timestamp_to_string.dart';
import '../components/message_baloon.dart';

class ConversationPage extends StatefulWidget {
  const ConversationPage({
    super.key,
    required this.conversationId,
    required this.talkingTo,
  });
  final String conversationId;
  final Widget talkingTo;

  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage> {
  final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController scrollController = ScrollController();
  final currentUser = FirebaseAuth.instance.currentUser!;

  void sendMessage(String text, Uint8List? loadedImage) async {
    final conversationRef =
        FirebaseFirestore.instance.collection('Conversations').doc(widget.conversationId);
    // update conversation
    final messageRef = await conversationRef.collection('Messages').add({
      'sender': currentUser.email,
      'text': text,
      'timestamp': Timestamp.now(),
    });
    if (loadedImage != null) {
      addImageToMessage(messageRef.id, loadedImage);
    }

    // scroll to most recent message
    scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.decelerate,
    );

    // notify participants that there's a new message and the update time
    final List participants = (await conversationRef.get())['participants'];
    for (String participant in participants) {
      if (participant != currentUser.email) {
        final updateTime = Timestamp.now();
        FirebaseFirestore.instance
            .collection('User Profile')
            .doc(participant)
            .collection('Conversations')
            .doc(currentUser.email)
            .set({
          'lastUpdated': updateTime,
          'seen': false,
        }, SetOptions(merge: true));

        FirebaseFirestore.instance
            .collection('User Profile')
            .doc(currentUser.email)
            .collection('Conversations')
            .doc(participant)
            .set({
          'lastUpdated': updateTime,
        }, SetOptions(merge: true));
      }
    }
  }

  void addImageToMessage(String messageId, Uint8List image) {
    // TODO: implement: add image
  }

  void messageOptions() {
    // TODO: Implement options

    // delete message;

    // edit messagge;

    // atach to message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,

      // drawer: const DrawerNavigation(),
      endDrawer: const DrawerConversations(),
      appBar: AppBar(
        centerTitle: false,
        title: widget.talkingTo,
        actions: [
          IconButton(
            onPressed: () {
              scaffoldKey.currentState?.openEndDrawer();
            },
            icon: const Icon(Icons.message),
          )
        ],
      ),
      body: Column(
        children: [
          // conversation
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('Conversations')
                    .doc(widget.conversationId)
                    .collection('Messages')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    if (snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('start a conversation'));
                    }
                    final int itemCount = snapshot.data!.docs.length;
                    return ListView.builder(
                      controller: scrollController,
                      shrinkWrap: true,
                      reverse: true,
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        final message = snapshot.data!.docs[index];
                        late final bool showsender;
                        if (index == itemCount - 1 ||
                            snapshot.data!.docs[index + 1]['sender'] != message['sender']) {
                          showsender = true;
                        } else {
                          showsender = false;
                        }
                        return MessageBaloon(
                          sender: message['sender'],
                          text: message['text'],
                          timestamp: timestampToString(message['timestamp']),
                          showSender: showsender,
                          onLongPress: messageOptions,
                        );
                      },
                    );
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              ),
            ),
          ),
          // post message
          InputField(onSendTap: sendMessage, dismissKeyboardOnSend: false),
        ],
      ),
    );
  }
}
