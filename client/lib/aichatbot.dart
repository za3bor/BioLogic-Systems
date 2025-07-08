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

class _AIChatbotPageState extends State<AIChatbotPage> {
  final TextEditingController _plantController = TextEditingController();
  final TextEditingController _customPromptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<ChatMessage> messages = [];
  bool isLoading = false;
  String selectedPromptTemplate = '';
  bool _isNearBottom = true;

  final List<PromptTemplate> promptTemplates = [
    PromptTemplate(
      title: 'Growing Guide',
      icon: Icons.eco,
      template: 'Provide a comprehensive growing guide for {plant}. Include soil requirements, climate needs, planting schedule, watering instructions, fertilization, common diseases, pest management, and harvesting tips.',
    ),
    PromptTemplate(
      title: 'Disease Prevention',
      icon: Icons.healing,
      template: 'What are the most common diseases affecting {plant}? Provide detailed prevention strategies, early detection signs, and organic treatment methods.',
    ),
    PromptTemplate(
      title: 'Pest Management',
      icon: Icons.bug_report,
      template: 'Help me manage pests for {plant}. Include identification of common pests, natural pest control methods, companion planting suggestions, and integrated pest management strategies.',
    ),
    PromptTemplate(
      title: 'Soil & Fertilization',
      icon: Icons.landscape,
      template: 'What are the ideal soil conditions for {plant}? Provide information about soil pH, nutrients, organic matter, drainage requirements, and fertilization schedule.',
    ),
    PromptTemplate(
      title: 'Climate Adaptation',
      icon: Icons.wb_sunny,
      template: 'How can I adapt {plant} growing to different climate conditions? Include information about temperature tolerance, season extension, greenhouse growing, and climate change adaptation.',
    ),
    PromptTemplate(
      title: 'Harvest & Storage',
      icon: Icons.agriculture,
      template: 'When and how should I harvest {plant}? Provide detailed harvesting techniques, post-harvest handling, storage methods, and value-added processing options.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
    // Add scroll listener to track scroll position
    _scrollController.addListener(_scrollListener);
    // Ensure scroll controller is ready and scroll to bottom after welcome message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottomInstant();
    });
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      double threshold = 100.0; // pixels from bottom
      double position = _scrollController.position.pixels;
      double maxScrollExtent = _scrollController.position.maxScrollExtent;
      
      bool newIsNearBottom = (maxScrollExtent - position) <= threshold;
      if (newIsNearBottom != _isNearBottom) {
        setState(() {
          _isNearBottom = newIsNearBottom;
        });
      }
    }
  }

  void _addWelcomeMessage() {
    messages.add(ChatMessage(
      text: "🌱 Welcome to AirWise AI Farming Assistant!\n\nI'm here to help you grow healthy vegetables. Choose a prompt template below, enter your plant name, and I'll provide comprehensive growing guidance tailored to your needs.",
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

    // Always scroll when user sends a message
    _scrollToBottomForced();

    try {
      final response = await http.post(
        Uri.parse('http://$ipAddress/api/ai-chat'),
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
      // Smooth scroll after AI response if user is near bottom
      _scrollToBottom();
    }
  }

  void _addErrorMessage() {
    setState(() {
      messages.add(ChatMessage(
        text: "Sorry, I'm having trouble connecting right now. Please try again later.",
        isUser: false,
        timestamp: DateTime.now(),
        isError: true,
      ));
    });
    // Always scroll to bottom when error message is added
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
  }

  void _sendTemplatePrompt() {
    String plant = _plantController.text.trim();
    String prompt = _customPromptController.text.trim();
    
    if (plant.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a plant name'),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a prompt template or write a custom prompt'),
          backgroundColor: Colors.red.shade600,
        ),
      );
      return;
    }

    String finalPrompt = prompt.replaceAll('{plant}', plant);
    _sendMessage(finalPrompt);
    
    // Clear the input fields
    _plantController.clear();
    _customPromptController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: Text(
          'AI Farming Assistant',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 6,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Column(
        children: [
          // Chat messages area
          Expanded(
            flex: 3,
            child: Container(
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(16),
                physics: AlwaysScrollableScrollPhysics(),
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
          
          // Input area
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Choose a prompt template:',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade700,
                      ),
                    ),
                    SizedBox(height: 8),
                    
                    // Prompt templates grid
                    SizedBox(
                      height: 200, // Fixed height for grid
                      child: GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: promptTemplates.length,
                        itemBuilder: (context, index) {
                          final template = promptTemplates[index];
                          return _buildTemplateCard(template);
                        },
                      ),
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Plant name input
                    TextField(
                      controller: _plantController,
                      decoration: InputDecoration(
                        hintText: 'Enter plant name (e.g., tomatoes, carrots)',
                        prefixIcon: Icon(Icons.grass, color: Colors.green.shade600),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    // Custom prompt input
                    TextField(
                      controller: _customPromptController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Customize your prompt or use template...',
                        prefixIcon: Icon(Icons.edit, color: Colors.green.shade600),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.green.shade700, width: 2),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: 12),
                    
                    // Send button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isLoading ? null : _sendTemplatePrompt,
                        icon: Icon(Icons.send),
                        label: Text(
                          'Ask AI Assistant',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // Floating action button to scroll to bottom
      if (!_isNearBottom)
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.green.shade700,
            onPressed: () {
              _scrollToBottomForced();
            },
            child: Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white,
            ),
          ),
        ),
    ],
  ),
);
  }

  Widget _buildTemplateCard(PromptTemplate template) {
    bool isSelected = selectedPromptTemplate == template.template;
    
    return GestureDetector(
      onTap: () => _useTemplate(template),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? Colors.green.shade100 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.green.shade700 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              template.icon,
              color: isSelected ? Colors.green.shade700 : Colors.grey.shade600,
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              template.title,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.green.shade700 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              backgroundColor: message.isError ? Colors.red.shade700 : Colors.green.shade700,
              child: Icon(
                message.isError ? Icons.error : Icons.eco,
                color: Colors.white,
                size: 20,
              ),
            ),
            SizedBox(width: 8),
          ],
          
          Flexible(
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: message.isUser 
                    ? Colors.green.shade700 
                    : message.isError 
                        ? Colors.red.shade50
                        : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormattedText(
                    message.text,
                    baseColor: message.isUser ? Colors.white : Colors.black87,
                  ),
                  SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: GoogleFonts.nunito(
                      color: message.isUser 
                          ? Colors.white70 
                          : Colors.grey.shade600,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (message.isUser) ...[
            SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: Colors.blue.shade700,
              child: Icon(
                Icons.person,
                color: Colors.white,
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
      margin: EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.green.shade700,
            child: Icon(Icons.eco, color: Colors.white, size: 20),
          ),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
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
                SizedBox(width: 8),
                Text(
                  'AI is thinking...',
                  style: GoogleFonts.nunito(
                    color: Colors.grey.shade600,
                    fontSize: 14,
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
        spans.add(TextSpan(text: '\n'));
        continue;
      }
      
      // Handle headers (lines starting with **)
      if (line.trim().startsWith('**') && line.trim().endsWith('**') && line.trim().length > 4) {
        String headerText = line.trim().substring(2, line.trim().length - 2);
        spans.add(TextSpan(
          text: '$headerText\n',
          style: GoogleFonts.nunito(
            color: baseColor,
            fontSize: 16,
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
        spans.add(TextSpan(text: '\n'));
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
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
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

  PromptTemplate({
    required this.title,
    required this.icon,
    required this.template,
  });
} 