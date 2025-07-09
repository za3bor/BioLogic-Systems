import 'dart:convert';
import 'package:airwise/constant.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class AIChatbotPage extends StatefulWidget {
  const AIChatbotPage({super.key});

  @override
  State<AIChatbotPage> createState() => _AIChatbotPageState();
}

class _AIChatbotPageState extends State<AIChatbotPage> with TickerProviderStateMixin {
  final TextEditingController _plantController = TextEditingController();
  final TextEditingController _customPromptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _plantFocusNode = FocusNode();
  final FocusNode _promptFocusNode = FocusNode();
  
  List<ChatMessage> messages = [];
  bool isLoading = false;
  String selectedPromptTemplate = '';
  bool _isNearBottom = true;
  bool _isInputExpanded = false;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  final List<PromptTemplate> promptTemplates = [
    PromptTemplate(
      title: 'Growing Guide',
      icon: Icons.eco,
      color: Colors.green,
      template: 'Provide a comprehensive growing guide for {plant}. Include soil requirements, climate needs, planting schedule, watering instructions, fertilization, common diseases, pest management, and harvesting tips.',
    ),
    PromptTemplate(
      title: 'Disease Prevention',
      icon: Icons.local_hospital,
      color: Colors.red,
      template: 'What are the most common diseases affecting {plant}? Provide detailed prevention strategies, early detection signs, and organic treatment methods.',
    ),
    PromptTemplate(
      title: 'Pest Management',
      icon: Icons.bug_report,
      color: Colors.orange,
      template: 'Help me manage pests for {plant}. Include identification of common pests, natural pest control methods, companion planting suggestions, and integrated pest management strategies.',
    ),
    PromptTemplate(
      title: 'Soil & Fertilization',
      icon: Icons.terrain,
      color: Colors.brown,
      template: 'What are the ideal soil conditions for {plant}? Provide information about soil pH, nutrients, organic matter, drainage requirements, and fertilization schedule.',
    ),
    PromptTemplate(
      title: 'Climate Adaptation',
      icon: Icons.wb_sunny,
      color: Colors.amber,
      template: 'How can I adapt {plant} growing to different climate conditions? Include information about temperature tolerance, season extension, greenhouse growing, and climate change adaptation.',
    ),
    PromptTemplate(
      title: 'Harvest & Storage',
      icon: Icons.agriculture,
      color: Colors.purple,
      template: 'When and how should I harvest {plant}? Provide detailed harvesting techniques, post-harvest handling, storage methods, and value-added processing options.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
    _scrollController.addListener(_scrollListener);
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeInOut),
    );
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottomInstant();
    });
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      double threshold = 100.0;
      double position = _scrollController.position.pixels;
      double maxScrollExtent = _scrollController.position.maxScrollExtent;
      
      bool newIsNearBottom = (maxScrollExtent - position) <= threshold;
      if (newIsNearBottom != _isNearBottom) {
        setState(() {
          _isNearBottom = newIsNearBottom;
        });
        
        if (_isNearBottom) {
          _fabAnimationController.reverse();
        } else {
          _fabAnimationController.forward();
        }
      }
    }
  }

  void _addWelcomeMessage() {
    messages.add(ChatMessage(
      text: "🌱 **Welcome to AirWise AI Farming Assistant!**\n\nI'm here to help you grow healthy vegetables and optimize your farming practices. \n\n**How to get started:**\n• Choose a topic from the cards below\n• Enter your plant name\n• Customize your question if needed\n• Get personalized farming advice!\n\nLet's grow something amazing together! 🌾",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _sendMessage(String prompt) async {
    if (prompt.trim().isEmpty) return;

    setState(() {
      messages.add(ChatMessage(
        text: prompt,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      isLoading = true;
    });

    _scrollToBottomForced();

    try {
      final response = await http.post(
        Uri.parse('https://$ipAddress/api/ai-chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          messages.add(ChatMessage(
            text: data['response'] ?? 'No response received.',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      } else {
        _addErrorMessage();
      }
    } catch (e) {
      _addErrorMessage();
    } finally {
      setState(() {
        isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _addErrorMessage() {
    setState(() {
      messages.add(ChatMessage(
        text: "⚠️ **Connection Error**\n\nI'm having trouble connecting to the server right now. Please check your internet connection and try again.\n\nIf the problem persists, please contact support.",
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      ));
    });
    _scrollToBottomForced();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && _isNearBottom) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToBottomInstant() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  void _scrollToBottomForced() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _useTemplate(PromptTemplate template) {
    setState(() {
      selectedPromptTemplate = template.template;
      _customPromptController.text = template.template;
    });
    
    // Add haptic feedback
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      // Light haptic feedback for iOS
    }
  }

  void _sendTemplatePrompt() {
    String plant = _plantController.text.trim();
    String prompt = _customPromptController.text.trim();
    
    if (plant.isEmpty) {
      _showSnackBar('Please enter a plant name', isError: true);
      _plantFocusNode.requestFocus();
      return;
    }

    if (prompt.isEmpty) {
      _showSnackBar('Please select a topic or write a custom prompt', isError: true);
      _promptFocusNode.requestFocus();
      return;
    }

    String finalPrompt = prompt.replaceAll('{plant}', plant);
    _sendMessage(finalPrompt);
    
    // Clear inputs and collapse input area
    _plantController.clear();
    _customPromptController.clear();
    setState(() {
      selectedPromptTemplate = '';
      _isInputExpanded = false;
    });
    
    // Unfocus to hide keyboard
    FocusScope.of(context).unfocus();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.eco,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AirWise AI',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Farming Assistant',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isInputExpanded = !_isInputExpanded;
              });
            },
            icon: Icon(
              _isInputExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
              color: Colors.white,
            ),
            tooltip: _isInputExpanded ? 'Collapse input' : 'Expand input',
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.green.shade700,
                    Colors.grey.shade50,
                  ],
                  stops: const [0.0, 0.1],
                ),
              ),
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: messages.length + (isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length && isLoading) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessageBubble(messages[index]);
                    },
                  ),
                ),
              ),
            ),
          ),
          
          // Input area
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                                 // Quick templates section
                 Container(
                   height: _isInputExpanded ? 160 : 120,
                   padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Quick Topics',
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                                             Expanded(
                         child: SizedBox(
                           height: 80,
                           child: ListView.builder(
                             scrollDirection: Axis.horizontal,
                             itemCount: promptTemplates.length,
                             itemBuilder: (context, index) {
                               final template = promptTemplates[index];
                               return Padding(
                                 padding: EdgeInsets.only(
                                   right: index == promptTemplates.length - 1 ? 0 : 12,
                                 ),
                                 child: _buildTemplateChip(template),
                               );
                             },
                           ),
                         ),
                       ),
                    ],
                  ),
                ),
                
                // Input fields
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    children: [
                      // Plant name input
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: _plantController,
                          focusNode: _plantFocusNode,
                          decoration: InputDecoration(
                            hintText: 'What plant are you growing?',
                            hintStyle: GoogleFonts.nunito(
                              color: Colors.grey.shade500,
                            ),
                            prefixIcon: Icon(
                              Icons.grass,
                              color: Colors.green.shade600,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Custom prompt input
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: _customPromptController,
                          focusNode: _promptFocusNode,
                          maxLines: _isInputExpanded ? 3 : 2,
                          decoration: InputDecoration(
                            hintText: 'Your question will appear here...',
                            hintStyle: GoogleFonts.nunito(
                              color: Colors.grey.shade500,
                            ),
                            prefixIcon: Icon(
                              Icons.edit_outlined,
                              color: Colors.green.shade600,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Send button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _sendTemplatePrompt,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 2,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isLoading) ...[
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Getting Answer...',
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ] else ...[
                                Icon(Icons.send_rounded, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Ask AI Assistant',
                                  style: GoogleFonts.nunito(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: ScaleTransition(
        scale: _fabAnimation,
        child: FloatingActionButton(
          mini: true,
          backgroundColor: Colors.green.shade700,
          onPressed: _scrollToBottomForced,
          child: const Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildTemplateChip(PromptTemplate template) {
    bool isSelected = selectedPromptTemplate == template.template;
    
    return GestureDetector(
      onTap: () => _useTemplate(template),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 90,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? template.color.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? template.color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              template.icon,
              color: isSelected ? template.color : Colors.grey.shade600,
              size: 20,
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                template.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? template.color : Colors.grey.shade700,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: message.isError ? Colors.red.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                message.isError ? Icons.error_outline : Icons.eco,
                color: message.isError ? Colors.red.shade700 : Colors.green.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: message.isUser 
                    ? Colors.green.shade700 
                    : message.isError 
                        ? Colors.red.shade50
                        : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha:0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormattedText(
                    message.text,
                    baseColor: message.isUser ? Colors.white : Colors.black87,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTime(message.timestamp),
                    style: GoogleFonts.nunito(
                      color: message.isUser 
                          ? Colors.white70 
                          : Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (message.isUser) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.person,
                color: Colors.blue.shade700,
                size: 20,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.eco,
              color: Colors.green.shade700,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade700),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'AI is analyzing...',
                  style: GoogleFonts.nunito(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildFormattedText(String text, {required Color baseColor}) {
    List<TextSpan> spans = [];
    List<String> lines = text.split('\n');
    
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      
      if (line.trim().isEmpty) {
        spans.add(const TextSpan(text: '\n'));
        continue;
      }
      
      // Handle headers (lines starting with **)
      if (line.trim().startsWith('**') && line.trim().endsWith('**') && line.trim().length > 4) {
        String headerText = line.trim().substring(2, line.trim().length - 2);
        spans.add(TextSpan(
          text: '$headerText\n',
          style: GoogleFonts.nunito(
            color: baseColor,
            fontSize: 17,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
        ));
        continue;
      }
      
      // Parse line for bold text and bullet points
      List<TextSpan> lineSpans = _parseLineForFormatting(line, baseColor);
      spans.addAll(lineSpans);
      
      // Add newline if not the last line
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }
    
    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.left,
    );
  }

  List<TextSpan> _parseLineForFormatting(String line, Color baseColor) {
    List<TextSpan> spans = [];
    
    // Handle bullet points
    if (line.trim().startsWith('•') || line.trim().startsWith('*')) {
      String bulletText = line.trim();
      if (bulletText.startsWith('*') && !bulletText.startsWith('**')) {
        bulletText = '• ${bulletText.substring(1).trim()}';
      }
      
      List<TextSpan> bulletSpans = _parseBoldText(bulletText, baseColor, true);
      spans.addAll(bulletSpans);
      return spans;
    }
    
    // Parse bold text for regular lines
    List<TextSpan> regularSpans = _parseBoldText(line, baseColor, false);
    spans.addAll(regularSpans);
    
    return spans;
  }

  List<TextSpan> _parseBoldText(String text, Color baseColor, bool isBulletPoint) {
    List<TextSpan> spans = [];
    RegExp boldRegex = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;
    
    Iterable<RegExpMatch> matches = boldRegex.allMatches(text);
    
    for (RegExpMatch match in matches) {
      // Add text before the bold part
      if (match.start > lastEnd) {
        String beforeText = text.substring(lastEnd, match.start);
        spans.add(TextSpan(
          text: beforeText,
          style: GoogleFonts.nunito(
            color: baseColor,
            fontSize: 14,
            height: 1.4,
            fontWeight: isBulletPoint ? FontWeight.w500 : FontWeight.normal,
          ),
        ));
      }
      
      // Add the bold text
      String boldText = match.group(1) ?? '';
      spans.add(TextSpan(
        text: boldText,
        style: GoogleFonts.nunito(
          color: baseColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          height: 1.4,
        ),
      ));
      
      lastEnd = match.end;
    }
    
    // Add remaining text after the last bold part
    if (lastEnd < text.length) {
      String remainingText = text.substring(lastEnd);
      spans.add(TextSpan(
        text: remainingText,
        style: GoogleFonts.nunito(
          color: baseColor,
          fontSize: 14,
          height: 1.4,
          fontWeight: isBulletPoint ? FontWeight.w500 : FontWeight.normal,
        ),
      ));
    }
    
    // If no bold text was found, add the entire text
    if (spans.isEmpty) {
      spans.add(TextSpan(
        text: text,
        style: GoogleFonts.nunito(
          color: baseColor,
          fontSize: 14,
          height: 1.4,
          fontWeight: isBulletPoint ? FontWeight.w500 : FontWeight.normal,
        ),
      ));
    }
    
    return spans;
  }

  @override
  void dispose() {
    _plantController.dispose();
    _customPromptController.dispose();
    _plantFocusNode.dispose();
    _promptFocusNode.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _fabAnimationController.dispose();
    super.dispose();
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}

class PromptTemplate {
  final String title;
  final IconData icon;
  final String template;
  final Color color;

  PromptTemplate({
    required this.title,
    required this.icon,
    required this.template,
    required this.color,
  });
} 
