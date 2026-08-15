# Flutter plugins are registered by generated code. Keep only members that
# Android or androidx explicitly marks for reflective runtime access.
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# Retain source/line metadata so release crash symbols remain useful after
# flutter symbolize is applied to the separately archived Dart symbols.
-keepattributes SourceFile,LineNumberTable
