module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  testMatch: ["**/src/**/*.test.ts"],
  transform: {
    "^.+\\.ts$": ["ts-jest", {tsconfig: {noUnusedLocals: false}}],
  },
};
