CREATE TABLE "tasks" (
    "id" INTEGER NOT NULL UNIQUE,
    "title" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "due_date" TIMESTAMP NOT NULL,
    "status" TEXT NOT NULL CHECK("status" IN ('to-do', 'in progress', 'done')),
    "blocked_by" INTEGER,
    PRIMARY KEY("id"),
    FOREIGN KEY("blocked_by") REFERENCES "tasks"("id")
);