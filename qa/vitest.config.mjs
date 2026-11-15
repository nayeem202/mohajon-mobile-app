// Keep Angular's Vitest workers within the WSL/NTFS environment's resources.
export default {
  test: {
    pool: 'threads',
    maxWorkers: 1,
    fileParallelism: false,
    testTimeout: 30000,
    hookTimeout: 30000,
  },
};
