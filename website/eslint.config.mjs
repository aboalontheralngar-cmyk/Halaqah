import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  {
    // خط أساس انتقالي لـ P6.1: تبقى أنماط effects القديمة ظاهرة كتحذير،
    // بينما أصبحت الأنواع الصريحة وقواعد الصياغة أخطاء مانعة للدمج.
    rules: {
      "@typescript-eslint/no-explicit-any": "error",
      "react-hooks/set-state-in-effect": "warn",
      "prefer-const": "error",
      "react/no-unescaped-entities": "error",
    },
  },
  // Override default ignores of eslint-config-next.
  globalIgnores([
    // Default ignores of eslint-config-next:
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
  ]),
]);

export default eslintConfig;
