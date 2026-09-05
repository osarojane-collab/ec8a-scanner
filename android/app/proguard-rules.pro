# EC8A Scanner - release R8 rules.
#
# google_mlkit_text_recognition references optional script recognizers
# (Chinese, Devanagari, Japanese, Korean) that are not bundled with this app
# (we only use the Latin recognizer). These -dontwarn rules are the ones R8
# generated in build/app/outputs/mapping/release/missing_rules.txt.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
